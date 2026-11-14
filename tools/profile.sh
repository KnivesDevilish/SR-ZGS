#!/usr/bin/env bash
# =============================================================================
# SR-Source - measure where the game's time really goes, with Linux's perf.
#
#   tools/profile.sh <name>
#
# Starts SR-Source (build/chassis) under `perf record`, the game included
# (perf follows the launcher's child processes). Play the part you want to
# measure, then close the game and the launcher. It writes
#   build/perf/<name>.data   the recording (for perf report, if you want more)
#   build/perf/<name>.txt    a short summary: time per thread, per library and
#                            per function
# and prints the summary. Choose the CPU core in the launcher's Settings, or
# force it for one run:
#   MODERNGEKKO_STATICRECOMP=0 tools/profile.sh zg-jit64
#   MODERNGEKKO_STATICRECOMP=1 tools/profile.sh zg-staticrecomp
#
# Code JIT64 writes while the game runs has no name for perf: it shows as
# [unknown] or as an anonymous mapping. The recompiled code shows as
# g<GAME_ID>_recomp.so, function by function (func_<address>).
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
die() { echo "error: $*" >&2; exit 1; }

NAME="${1:-}"
[[ -n "$NAME" ]] || die "usage: tools/profile.sh <name>   (for example: tools/profile.sh zg-staticrecomp)"
[[ "$NAME" =~ ^[A-Za-z0-9._-]+$ ]] || die "the name may only have letters, numbers, '.', '_' and '-'"

CHASSIS="$ROOT/build/chassis"
[[ -x "$CHASSIS/SR-Source" ]] || die "no build/chassis/SR-Source: build it first (tools/build_tools.sh --chassis)"

if ! command -v perf > /dev/null; then
  distro="$(sed -n 's/^ID=//p' /etc/os-release 2>/dev/null | tr -d '"')"
  echo "perf isn't installed here. Install it (inside distrobox):"
  case "$distro" in
    fedora) echo "  sudo dnf install perf" ;;
    arch) echo "  sudo pacman -S perf" ;;
    ubuntu | debian) echo "  sudo apt install linux-perf   (or linux-tools-generic on Ubuntu)" ;;
    *) echo "  the package is usually called perf, linux-perf or linux-tools" ;;
  esac
  exit 1
fi

paranoid="$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo 2)"
if (( paranoid > 2 )); then
  echo "Your system doesn't let programs measure themselves (perf_event_paranoid=$paranoid)."
  echo "On your system, outside distrobox, allow it until the next restart:"
  echo "  sudo sysctl kernel.perf_event_paranoid=2"
  exit 1
fi

OUT="$ROOT/build/perf"
mkdir -p "$OUT"
DATA="$OUT/$NAME.data"
SUMMARY="$OUT/$NAME.txt"

if [[ -n "${MODERNGEKKO_STATICRECOMP:-}" ]]; then
  CORE="MODERNGEKKO_STATICRECOMP=$MODERNGEKKO_STATICRECOMP"
else
  CORE="the one in Settings (config.ini)"
fi
echo "Recording. Play the part you want to measure, then close the game and the launcher."
echo "CPU core: $CORE"
# cpu-clock is a software clock: it works in containers and without access to
# the processor's own counters. 999 samples a second per thread.
(cd "$CHASSIS" && perf record -e cpu-clock -F 999 -o "$DATA" -- ./SR-Source) \
  || echo "(perf record ended with an error; the summary below may be partial)"

[[ -s "$DATA" ]] || die "nothing was recorded in $DATA"

# One perf report table, without its header and blank lines.
table() {
  perf report -i "$DATA" --stdio --no-children "$@" 2>/dev/null | grep -v '^#' | grep -v '^[[:space:]]*$' || true
}

{
  echo "SR-Source perf summary: $NAME"
  echo "recorded: $(date '+%Y-%m-%d %H:%M')   CPU core: $CORE"
  grep -m1 '^cpu core:' "$HOME/.local/share/sr-source/Logs/ModernGekko.log" 2>/dev/null || true
  echo
  echo "== Time per thread =="
  table --sort comm --percent-limit 1 | head -n 15
  echo
  echo "== Time per library =="
  table --sort dso --percent-limit 0.5 | head -n 20
  echo
  echo "== Top functions =="
  table --sort dso,sym --percent-limit 0.3 | head -n 60
} > "$SUMMARY"

cat "$SUMMARY"
echo
echo "Summary saved in: $SUMMARY"
