#!/usr/bin/env bash
# =============================================================================
# SR:ZGS - recompile main.dol with DolRecomp and stage the result for CMake.
#
#   game_assets/sys/main.dol --DolRecomp--> src/recompiled/<GAME_ID>/
#       generated.h  generated_smc.txt  main.dol  chunks/*.c  <manifest>.c
#
# Settings live in tools/dolrecomp/recomp.conf. Safe to re-run: the output
# directory is replaced atomically, so a failed run never leaves a half tree.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tools/dolrecomp/recomp.conf
source "${SRZGS_RECOMP_CONF:-$ROOT/tools/dolrecomp/recomp.conf}"

die()  { echo "error: $*" >&2; exit 1; }
note() { echo "[recompile] $*"; }

GAME_ID="${GAME_ID:?GAME_ID is missing in recomp.conf}"
CPU="${CPU:-broadway}"
BACKEND="${BACKEND:-c}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
DOLRECOMP_BIN="${DOLRECOMP_BIN:-$ROOT/build/dolrecomp/dolrecomp}"
ASSETS="${ASSETS_DIR:-$ROOT/game_assets}"

[[ "$DOLRECOMP_BIN" = /* ]] || DOLRECOMP_BIN="$ROOT/$DOLRECOMP_BIN"
[[ -x "$DOLRECOMP_BIN" ]] || die "DolRecomp not built ($DOLRECOMP_BIN). Run: tools/build_tools.sh"

# --- 1. Locate the DOL ------------------------------------------------------
if [[ -z "${DOL_PATH:-}" ]]; then
  if   [[ -f "$ASSETS/sys/main.dol" ]]; then DOL_PATH="$ASSETS/sys/main.dol"
  elif [[ -f "$ASSETS/main.dol"     ]]; then DOL_PATH="$ASSETS/main.dol"
  else die "main.dol not found in $ASSETS (looked in sys/ and the top level)"
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

note "DolRecomp: $DOLRECOMP_BIN"
note "Input:     $DOL_PATH  (id=$GAME_ID cpu=$CPU backend=$BACKEND jobs=$JOBS)"
# EXTRA_ARGS is intentionally word-split.
# shellcheck disable=SC2086
"$DOLRECOMP_BIN" -j"$JOBS" --backend="$BACKEND" --cpu "$CPU" $EXTRA_ARGS \
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
compgen -G "$NEW/chunks/*.c" > /dev/null || die "no chunks/*.c were generated (see $LOG)"

{
  echo "game_id=$GAME_ID"
  echo "cpu=$CPU"
  echo "backend=$BACKEND"
  echo "dol_sha256=$(sha256sum "$DOL_PATH" | cut -d' ' -f1)"
  echo "dolrecomp_sha256=$(sha256sum "$DOLRECOMP_BIN" | cut -d' ' -f1)"
  echo "generated_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$NEW/recomp.stamp"

rm -rf "$FINAL.old"
[[ -d "$FINAL" ]] && mv "$FINAL" "$FINAL.old"
mv "$NEW" "$FINAL"
rm -rf "$FINAL.old"

CHUNKS="$(find "$FINAL/chunks" -name '*.c' | wc -l)"
note "done: $CHUNKS chunk files in src/recompiled/$GAME_ID"
note "full log: $LOG   (search it for 'smc', 'suspicious', 'unknown')"
note "next: cmake --preset release && cmake --build --preset release"
