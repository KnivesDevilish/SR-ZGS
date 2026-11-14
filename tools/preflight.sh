#!/usr/bin/env bash
# =============================================================================
# SR-Source - check everything the runner needs BEFORE launching, so a first boot
# fails with a clear sentence instead of a runtime error.
#
#   tools/preflight.sh [GAME_ID | game_root] [module.so]
#
#   tools/preflight.sh            Sonic Riders: Zero Gravity (RS9E8P)
#   tools/preflight.sh GXEE8P     Sonic Riders (GameCube)
#
# Defaults: GAME_ID   = $SRZGS_GAME_ID, else the disc in game_root, else the
#                       one of tools/dolrecomp/recomp.conf (RS9E8P)
#           game_root = $SRZGS_GAME_ROOT, else <repo>/game_assets if it holds
#                       that game, else the copy the launcher extracted
#           module    = the newest g<GAME_ID>_recomp.* under <repo>/build/*/stage
# Exit status: 0 = ready, 1 = a blocking problem was found.
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GAME_ID="${SRZGS_GAME_ID:-}"
GAME_ROOT=""
if [[ "${1:-}" =~ ^[A-Z0-9]{6}$ && ! -d "${1:-}" ]]; then
  GAME_ID="$1"
else
  GAME_ROOT="${1:-}"
fi
MODULE="${2:-}"

if [[ -z "$GAME_ID" && -n "$GAME_ROOT" && -f "$GAME_ROOT/sys/boot.bin" ]]; then
  GAME_ID="$(head -c 6 "$GAME_ROOT/sys/boot.bin")"
fi
if [[ -z "$GAME_ID" ]]; then
  # shellcheck source=tools/dolrecomp/recomp.conf
  source "${SRZGS_RECOMP_CONF:-$ROOT/tools/dolrecomp/recomp.conf}"
  GAME_ID="${GAME_ID:?GAME_ID is missing in recomp.conf}"
fi
if [[ -z "$GAME_ROOT" ]]; then
  GAME_ROOT="${SRZGS_GAME_ROOT:-}"
fi
if [[ -z "$GAME_ROOT" ]]; then
  GAME_ROOT="$ROOT/game_assets"
  if [[ "$(head -c 6 "$GAME_ROOT/sys/boot.bin" 2>/dev/null || true)" != "$GAME_ID" ]]; then
    GAME_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/sr-source/games/$GAME_ID"
  fi
fi
errors=0
fail() { echo "  [FAIL] $*"; errors=$((errors + 1)); }
warn() { echo "  [warn] $*"; }
ok()   { echo "  [ ok ] $*"; }

# --- 1. Disc layout the runner (and Dolphin's directory loader) require ------
echo "Game: $GAME_ID"
echo "Game root: $GAME_ROOT"
for f in sys/boot.bin sys/bi2.bin sys/apploader.img sys/main.dol; do
  [[ -f "$GAME_ROOT/$f" ]] && ok "$f" || fail "$f missing (extract the WHOLE disc, not just main.dol)"
done
if [[ -d "$GAME_ROOT/files" ]] && [[ -n "$(ls -A "$GAME_ROOT/files" 2>/dev/null)" ]]; then
  ok "files/ ($(find "$GAME_ROOT/files" -type f | wc -l) files)"
else
  fail "files/ missing or empty"
fi

BOOT="$GAME_ROOT/sys/boot.bin"
if [[ -f "$BOOT" ]]; then
  id="$(head -c 6 "$BOOT")"
  [[ "$id" == "$GAME_ID" ]] && ok "disc ID $id" || fail "boot.bin says '$id', expected '$GAME_ID'"
  # A GameCube disc (G...) has its magic word at 0x1C, a Wii disc at 0x18.
  if [[ "$GAME_ID" == G* ]]; then
    magic="$(od -An -tx1 -j28 -N4 "$BOOT" | tr -d ' \n')"
    [[ "$magic" == "c2339f3d" ]] && ok "GameCube disc magic" || fail "boot.bin has no GameCube magic (got '$magic')"
  else
    magic="$(od -An -tx1 -j24 -N4 "$BOOT" | tr -d ' \n')"
    [[ "$magic" == "5d1c9ea3" ]] && ok "Wii disc magic" || fail "boot.bin has no Wii magic (got '$magic')"
  fi
fi

# --- 2. The DOL we recompiled must be the DOL we are about to boot -----------
STAMP="$ROOT/src/recompiled/$GAME_ID/recomp.stamp"
if [[ -f "$STAMP" && -f "$GAME_ROOT/sys/main.dol" ]]; then
  want="$(sed -n 's/^dol_sha256=//p' "$STAMP")"
  have="$(sha256sum "$GAME_ROOT/sys/main.dol" | cut -d' ' -f1)"
  if [[ "$want" == "$have" ]]; then ok "main.dol matches the recompiled one"
  else fail "sys/main.dol differs from the recompiled DOL: re-run tools/dolrecomp/recompile.sh $GAME_ID"; fi
elif [[ ! -f "$STAMP" ]]; then
  fail "no recompiled output ($STAMP): run tools/dolrecomp/recompile.sh $GAME_ID"
fi

# --- 3. Module ---------------------------------------------------------------
if [[ -z "$MODULE" ]]; then
  MODULE="$(ls -t "$ROOT"/build/*/stage/g"${GAME_ID}"_recomp.* 2>/dev/null | head -n1 || true)"
fi
if [[ -n "$MODULE" && -f "$MODULE" ]]; then ok "module: $MODULE"
else fail "no built module (g${GAME_ID}_recomp.*): cmake --preset quick && cmake --build --preset quick"; fi

# --- 4. Runner + its Sys/ data -----------------------------------------------
RUNNER="${SRZGS_RUNNER:-}"
if [[ -z "$RUNNER" ]]; then
  for d in "$ROOT/build/chassis" "$ROOT/build/chassis/Binaries" "$ROOT/external/ModernGekko/Binary/x64"; do
    for n in moderngekko-run moderngekko-run.exe; do
      [[ -x "$d/$n" ]] && { RUNNER="$d/$n"; break 2; }
    done
  done
fi
if [[ -n "$RUNNER" && -x "$RUNNER" ]]; then
  ok "runner: $RUNNER"
  [[ -d "$(dirname "$RUNNER")/Sys" ]] && ok "Sys/ next to the runner" \
    || fail "Sys/ is missing next to the runner (rebuild: tools/build_tools.sh --chassis)"
else
  fail "moderngekko-run not found: tools/build_tools.sh --chassis"
fi

# --- 5. Graphics hint (non-blocking) -----------------------------------------
if command -v vulkaninfo >/dev/null 2>&1; then
  if vulkaninfo --summary 2>/dev/null | grep -qi "deviceName"; then ok "Vulkan device found"
  else warn "vulkaninfo sees no device: set backend=OpenGL in the user config.ini"; fi
else
  warn "vulkaninfo not installed: cannot check Vulkan (package vulkan-tools); OpenGL is the fallback"
fi

echo
if ((errors)); then echo "preflight: $errors blocking problem(s)"; exit 1; fi
echo "preflight: ready"
