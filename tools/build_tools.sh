#!/usr/bin/env bash
# =============================================================================
# SR:ZGS - build the external tools from the pinned ModernGekko submodule.
#
#   tools/build_tools.sh            DolRecomp only (fast; all recompile.sh needs)
#   tools/build_tools.sh --chassis  also the ModernGekko runner (heavy: builds Dolphin)
#
# DolRecomp is built from the revision ModernGekko pins, so the generated code
# and the runtime that loads it always agree on the module ABI.
# Extra chassis CMake flags can be passed through CHASSIS_CMAKE_ARGS, e.g.
#   CHASSIS_CMAKE_ARGS="-DMODERNGEKKO_USER_DIRECTORY_IN_DOCUMENTS=ON" tools/build_tools.sh --chassis
# The runner's output location is determined by CMake.
# Its Sys/ data folder must be copied next to the executable.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MG="$ROOT/external/ModernGekko"
DR_SRC="$MG/vendor/dolphin/DolRecomp"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

die() { echo "error: $*" >&2; exit 1; }

[[ -f "$DR_SRC/CMakeLists.txt" ]] || die "missing $DR_SRC
  git submodule update --init --recursive      # then retry"

cmake -S "$DR_SRC" -B "$ROOT/build/dolrecomp" -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DDOLRECOMP_ENABLE_LLVM=OFF
cmake --build "$ROOT/build/dolrecomp" --target dolrecomp -j"$JOBS"
echo "DolRecomp: $ROOT/build/dolrecomp/dolrecomp"

if [[ "${1:-}" == "--chassis" ]]; then
  [[ -f "$MG/vendor/dolphin/Externals/SDL/SDL/CMakeLists.txt" ]] \
    || die "ModernGekko submodules are incomplete: git submodule update --init --recursive"
  "$ROOT/tools/check_chassis_deps.sh" || exit 1

  echo "Building the chassis with $JOBS jobs. This compiles Dolphin's core: expect a long build."
  cmake -S "$MG" -B "$ROOT/build/chassis" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DDOLRECOMP_ENABLE_LLVM=OFF \
        ${CHASSIS_CMAKE_ARGS:-} \
        -DMODERNGEKKO_FRONTEND_NAME="Sonic Riders: Zero Gravity Source" \
        -DMODERNGEKKO_LAUNCHER_OUTPUT_NAME="SR-ZGS" \
        -DMODERNGEKKO_REQUIRED_DISC_ID="RS9E8P" \
        -DMODERNGEKKO_DEFAULT_WINDOW_TITLE="Sonic Riders: Zero Gravity Source" \
        -DMODERNGEKKO_USER_DIRECTORY_NAME="sr-zgs" \
        -DMODERNGEKKO_LAUNCHER_BANNER="$ROOT/docs/SR-ZGS Artwork.png" \
        -DMODERNGEKKO_LAUNCHER_CONTROLLER_ART="$ROOT/docs/SR-ZGS Controller.png" \
        -DMODERNGEKKO_LAUNCHER_KEYBOARD_ART="$ROOT/docs/SR-ZGS Keyboard.png" \
        -DMODERNGEKKO_GAMECUBE_CONTROLLERS=ON

  cmake --build "$ROOT/build/chassis" \
        --target moderngekko-run moderngekko-launcher -j"$JOBS"

  RUNNER="$(find "$ROOT/build/chassis" -type f \
    -name "moderngekko-run" -perm /111 -print -quit)"

  [[ -n "$RUNNER" ]] || die "build finished but moderngekko-run is missing"

  RUNNER_DIR="$(dirname "$RUNNER")"
  [[ -d "$RUNNER_DIR/Sys" ]] || die "Sys/ was not copied next to the runner"

  LAUNCHER="$(find "$ROOT/build/chassis" -type f \
    -name "SR-ZGS" -perm /111 -print -quit)"

  [[ -n "$LAUNCHER" ]] || die "build finished but SR-ZGS launcher is missing"

  echo "Runner:    $RUNNER"
  echo "Launcher:  $LAUNCHER"
  echo "Next:      cmake --preset quick && cmake --build --preset quick --target srzgs_preflight"
fi
