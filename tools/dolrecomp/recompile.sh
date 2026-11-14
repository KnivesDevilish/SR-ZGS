#!/usr/bin/env bash
# =============================================================================
# SR-Source - recompile a game's main.dol with DolRecomp and stage the result
# for CMake.
#
#   tools/dolrecomp/recompile.sh            Sonic Riders: Zero Gravity (RS9E8P, Wii)
#   tools/dolrecomp/recompile.sh GXEE8P     Sonic Riders (GameCube)
#
#   <extracted game>/sys/main.dol --DolRecomp--> src/recompiled/<GAME_ID>/
#       generated.h  generated_smc.txt  main.dol  chunks/*.c  <manifest>.c
#
# Settings: tools/dolrecomp/recomp.conf for Zero Gravity, and
# tools/dolrecomp/recomp-<GAME_ID>.conf for another game (SRZGS_RECOMP_CONF
# names another file). The game is read from game_assets/ when it holds that
# game, else from the copy the launcher extracted (ASSETS_DIR names another
# folder). The C output then goes through tools/dolrecomp/fast_cache_ops.py,
# so data-cache loops run on in the recompiled code. BACKEND=llvm before the
# command uses DolRecomp's LLVM backend instead (tools/build_tools.sh builds
# it when LLVM 19 or 20 is installed); its output goes through
# tools/dolrecomp/fast_dispatch_lookup.py. Safe to re-run: the output
# directory is replaced atomically, so a failed run never leaves a half tree.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

die()  { echo "error: $*" >&2; exit 1; }
note() { echo "[recompile] $*"; }

# --- 0. Which game: its settings file ---------------------------------------
WANTED="${1:-}"
CONF_DIR="$ROOT/tools/dolrecomp"
if [[ -n "${SRZGS_RECOMP_CONF:-}" ]]; then
  CONF="$SRZGS_RECOMP_CONF"
elif [[ -n "$WANTED" && -f "$CONF_DIR/recomp-$WANTED.conf" ]]; then
  CONF="$CONF_DIR/recomp-$WANTED.conf"
elif [[ -z "$WANTED" ]] || grep -q "^GAME_ID=\"$WANTED\"" "$CONF_DIR/recomp.conf"; then
  CONF="$CONF_DIR/recomp.conf"
else
  die "no settings for '$WANTED': tools/dolrecomp/recomp-$WANTED.conf doesn't exist"
fi
# BACKEND=c or BACKEND=llvm before the command wins over the settings file:
#   BACKEND=llvm tools/dolrecomp/recompile.sh GXEE8P
BACKEND_FROM_COMMAND="${BACKEND:-}"
# shellcheck source=tools/dolrecomp/recomp.conf
source "$CONF"

GAME_ID="${GAME_ID:?GAME_ID is missing in $CONF}"
[[ -z "$WANTED" || "$GAME_ID" == "$WANTED" ]] || die "$CONF is for $GAME_ID, not $WANTED"
CPU="${CPU:-broadway}"
BACKEND="${BACKEND_FROM_COMMAND:-${BACKEND:-c}}"
[[ "$BACKEND" == "c" || "$BACKEND" == "llvm" ]] || die "BACKEND must be c or llvm, not '$BACKEND'"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
DOLRECOMP_BIN="${DOLRECOMP_BIN:-$ROOT/build/dolrecomp/dolrecomp}"
# Where the game is: ASSETS_DIR; else game_assets/ if it holds this game (the
# README's steps make it for Zero Gravity); else the copy the launcher
# extracted (Game Files) into the SR-Source user directory.
LAUNCHER_COPY="${XDG_DATA_HOME:-$HOME/.local/share}/sr-source/games/$GAME_ID"
if [[ -n "${ASSETS_DIR:-}" ]]; then
  ASSETS="$ASSETS_DIR"
else
  ASSETS="$ROOT/game_assets"
  IN_ASSETS="$(head -c 6 "$ASSETS/sys/boot.bin" 2>/dev/null || true)"
  if [[ "$IN_ASSETS" != "$GAME_ID" ]]; then
    if [[ -f "$LAUNCHER_COPY/sys/main.dol" ]]; then
      ASSETS="$LAUNCHER_COPY"
    elif [[ -n "$IN_ASSETS" ]]; then
      die "$GAME_ID isn't extracted: game_assets/ holds $IN_ASSETS, and there is no copy in
       $LAUNCHER_COPY
       Extract it with the launcher (Game Files), or set ASSETS_DIR=<folder>."
    fi
  fi
fi

[[ "$DOLRECOMP_BIN" = /* ]] || DOLRECOMP_BIN="$ROOT/$DOLRECOMP_BIN"
[[ -x "$DOLRECOMP_BIN" ]] || die "DolRecomp not built ($DOLRECOMP_BIN). Run: tools/build_tools.sh"
if [[ "$BACKEND" == "llvm" ]]; then
  DR_CACHE="$(dirname "$DOLRECOMP_BIN")/CMakeCache.txt"
  if [[ -f "$DR_CACHE" ]] && ! grep -q '^DOLRECOMP_ENABLE_LLVM:BOOL=ON' "$DR_CACHE"; then
    die "DolRecomp was built without its LLVM backend. Install LLVM 20's development files
       (Fedora: sudo dnf install llvm20-devel), run tools/build_tools.sh again, then this."
  fi
fi

# --- 1. Locate the DOL ------------------------------------------------------
if [[ -z "${DOL_PATH:-}" ]]; then
  if   [[ -f "$ASSETS/sys/main.dol" ]]; then DOL_PATH="$ASSETS/sys/main.dol"
  elif [[ -f "$ASSETS/main.dol"     ]]; then DOL_PATH="$ASSETS/main.dol"
  else die "main.dol of $GAME_ID not found in $ASSETS (looked in sys/ and the top level).
       Extract the game with the launcher (Game Files), or set ASSETS_DIR=<folder>."
  fi
fi
[[ "$DOL_PATH" = /* ]] || DOL_PATH="$ROOT/$DOL_PATH"
[[ -f "$DOL_PATH" ]] || die "DOL not found: $DOL_PATH"

# --- 2. Guard against the wrong region / revision ---------------------------
BOOT="$(dirname "$DOL_PATH")/boot.bin"
if [[ -f "$BOOT" ]]; then
  DISC_ID="$(head -c 6 "$BOOT")"
  [[ "$DISC_ID" == "$GAME_ID" ]] || die "boot.bin says '$DISC_ID' but GAME_ID is '$GAME_ID'"
else
  note "warning: no boot.bin next to the DOL, so the disc-ID check was skipped."
  note "         Booting later needs the full extracted disc (sys/ + files/), not just main.dol."
fi

# --- 3. Run DolRecomp into a scratch directory ------------------------------
STAGE="$ROOT/build/dolrecomp-out"
LOG="$ROOT/build/dolrecomp.log"
rm -rf "$STAGE"
mkdir -p "$STAGE"

# The LLVM backend, with the chassis' runtime (recompcore), only gives
# DolRecomp's "native" calling convention to functions that never touch
# memory, and a call between a native function and any other goes back to the
# dispatcher, its return too. A game, where most functions call small leaves,
# then crawls: a loop calling one function 100000 times took 200001 trips
# through the dispatcher (195 with --native-abi=off, 2326 with the C backend).
# Off, every function uses the same convention and they call each other
# directly. --native-abi in EXTRA_ARGS chooses otherwise.
BACKEND_ARGS=()
if [[ "$BACKEND" == "llvm" && " $EXTRA_ARGS " != *" --native-abi"* ]]; then
  BACKEND_ARGS=(--native-abi=off)
fi

note "DolRecomp: $DOLRECOMP_BIN"
note "Input:     $DOL_PATH  (id=$GAME_ID cpu=$CPU backend=$BACKEND ${BACKEND_ARGS[*]} jobs=$JOBS)"
# EXTRA_ARGS is intentionally word-split.
# shellcheck disable=SC2086
"$DOLRECOMP_BIN" -j"$JOBS" --backend="$BACKEND" "${BACKEND_ARGS[@]}" --cpu "$CPU" $EXTRA_ARGS \
    "$DOL_PATH" "$GAME_ID" "$STAGE" 2>&1 | tee "$LOG"

# --- 4. Find what DolRecomp emitted -----------------------------------------
# With the Wii title database installed it writes <ID>_generated/<ID>.h; without
# it, it silently falls back to generated/generated.h. Both are handled (the
# --cpu flag above is honoured either way).
if   [[ -f "$STAGE/${GAME_ID}_generated/${GAME_ID}.h" ]]; then
  GEN="$STAGE/${GAME_ID}_generated"; STEM="$GAME_ID"
elif [[ -f "$STAGE/generated/generated.h" ]]; then
  GEN="$STAGE/generated"; STEM="generated"
  note "title database not installed: DolRecomp used the generic output layout (fine for now)."
else
  die "DolRecomp produced no recognizable output under $STAGE (see $LOG)"
fi

# --- 5. Normalise into src/recompiled/<GAME_ID>/ ----------------------------
# Layout expected by the RecompCore module template:
#   generated.h  generated_smc.txt  main.dol  chunks/*.c
FINAL="$ROOT/src/recompiled/$GAME_ID"
NEW="$FINAL.new"
rm -rf "$NEW"
mkdir -p "$NEW"
cp -a "$GEN/." "$NEW/"

[[ -f "$NEW/generated.h" ]] || cp "$NEW/$STEM.h" "$NEW/generated.h"
cp "$DOL_PATH" "$NEW/main.dol"
if [[ ! -f "$NEW/generated_smc.txt" ]]; then
  if [[ -f "$NEW/${STEM}_smc.txt" ]]; then cp "$NEW/${STEM}_smc.txt" "$NEW/generated_smc.txt"
  else : > "$NEW/generated_smc.txt"
  fi
fi
# The C backend writes chunks/*.c, which CMake compiles; the LLVM backend
# writes chunks/*.o already compiled, listed in <STEM>.c, which the module
# template reads.
CHUNK_EXT="c"
[[ "$BACKEND" == "llvm" ]] && CHUNK_EXT="o"
compgen -G "$NEW/chunks/*.$CHUNK_EXT" > /dev/null || die "no chunks/*.$CHUNK_EXT were generated (see $LOG)"

# C: dcbf, dcbst and dcbi go on in place instead of returning to the
# dispatcher once per 32-byte line (the LLVM backend's objects already do).
# LLVM: the dispatcher finds a function's code in a few steps instead of one
# test per function. See each script.
command -v python3 > /dev/null || die "python3 is needed (it builds the module too)"
if [[ "$BACKEND" == "c" ]]; then
  python3 -I "$ROOT/tools/dolrecomp/fast_cache_ops.py" "$NEW" | sed 's/^/[recompile] /'
  POST="fast_cache_ops"
else
  python3 -I "$ROOT/tools/dolrecomp/fast_dispatch_lookup.py" "$NEW" | sed 's/^/[recompile] /'
  POST="fast_dispatch_lookup"
fi

{
  echo "game_id=$GAME_ID"
  echo "cpu=$CPU"
  echo "backend=$BACKEND"
  echo "backend_args=${BACKEND_ARGS[*]} $EXTRA_ARGS"
  echo "dol_sha256=$(sha256sum "$DOL_PATH" | cut -d' ' -f1)"
  echo "dolrecomp_sha256=$(sha256sum "$DOLRECOMP_BIN" | cut -d' ' -f1)"
  echo "generated_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "post=$POST"
} > "$NEW/recomp.stamp"

rm -rf "$FINAL.old"
[[ -d "$FINAL" ]] && mv "$FINAL" "$FINAL.old"
mv "$NEW" "$FINAL"
rm -rf "$FINAL.old"

CHUNKS="$(find "$FINAL/chunks" -name "*.$CHUNK_EXT" | wc -l)"
note "done: $CHUNKS chunk files (backend $BACKEND) in src/recompiled/$GAME_ID"
note "full log: $LOG   (search it for 'smc', 'suspicious', 'unknown')"
note "next: cmake --preset release && cmake --build --preset release"
note "      (it builds the module of every recompiled game and copies it beside SR-Source)"
