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
#   CHASSIS_CMAKE_ARGS="-DMODERNGEKKO_GAMECUBE_CONTROLLERS=ON" tools/build_tools.sh --chassis
# The runner lands in build/chassis/Binaries/ (Dolphin's CMake decides that),
# with its Sys/ data folder copied next to it by a post-build step.
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
        ${CHASSIS_CMAKE_ARGS:-}
  cmake --build "$ROOT/build/chassis" --target moderngekko-run -j"$JOBS"

  RUNNER="$ROOT/build/chassis/Binaries/moderngekko-run"
  [[ -x "$RUNNER" ]] || die "build finished but $RUNNER is missing"
  [[ -d "$ROOT/build/chassis/Binaries/Sys" ]] || die "Sys/ was not copied next to the runner"
  echo "Runner:    $RUNNER"
  echo "Next:      cmake --preset quick && cmake --build --preset quick --target srzgs_preflight"
fi
