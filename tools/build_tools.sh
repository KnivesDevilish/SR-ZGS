#!/usr/bin/env bash
# =============================================================================
# Sonic Riders: Source (SR-Source) - build the external tools from the pinned
# ModernGekko submodule.
#
#   tools/build_tools.sh            DolRecomp only (fast; all recompile.sh needs;
#                                   with LLVM 19 or 20 installed, its LLVM backend too)
#   tools/build_tools.sh --chassis  also the ModernGekko runner (heavy: builds Dolphin)
#
# DolRecomp is built from the revision ModernGekko pins, so the generated code
# and the runtime that loads it always agree on the module ABI.
# Extra chassis CMake flags can be passed through CHASSIS_CMAKE_ARGS, e.g.
#   CHASSIS_CMAKE_ARGS="-DMODERNGEKKO_USER_DIRECTORY_IN_DOCUMENTS=ON" tools/build_tools.sh --chassis
# SRZGS_SKIP_DOLRECOMP=1 leaves DolRecomp out, for a release build (only the
# launcher and the runner go into it; tools/package_release.sh packs them).
# On Windows it runs in Git Bash, inside a Visual Studio developer
# environment (as .github/workflows/release.yml does).
# The runner's output location is determined by CMake.
# Its Sys/ data folder must be copied next to the executable.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MG="$ROOT/external/ModernGekko"
DR_SRC="$MG/vendor/dolphin/DolRecomp"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

die() { echo "error: $*" >&2; exit 1; }

# Windows (Git Bash): paths as D:/... so CMake and the compiler read them too,
# the executables end in .exe (found by name alone), and the dependency check
# is Linux's.
EXE=""
EXECUTABLE=(-perm /111)
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    EXE=".exe"
    EXECUTABLE=()
    ROOT="$(cygpath -m "$ROOT")"
    MG="$ROOT/external/ModernGekko"
    DR_SRC="$MG/vendor/dolphin/DolRecomp"
    ;;
esac

[[ -f "$DR_SRC/CMakeLists.txt" ]] || die "missing $DR_SRC
  git submodule update --init --recursive      # then retry"

# DolRecomp's LLVM backend (BACKEND=llvm, see tools/dolrecomp/recompile.sh)
# needs the development files of LLVM 19 or 20, no other version: Fedora
# llvm20-devel, Debian and Ubuntu llvm-20-dev. They are looked for where
# those packages put them; SRZGS_LLVM_DIR=<folder with LLVMConfig.cmake>
# names another place, and SRZGS_LLVM=0 leaves the backend out. Without them
# DolRecomp is built as before, with the C backend only.
llvm_version() {
  sed -n 's/^set(PACKAGE_VERSION "\([0-9.]*\)").*/\1/p' "$1/LLVMConfigVersion.cmake" 2>/dev/null | head -n 1
}
find_llvm() {
  local dir config
  if [[ -n "${SRZGS_LLVM_DIR:-}" ]]; then
    echo "$SRZGS_LLVM_DIR"
    return 0
  fi
  local candidates=()
  for config in llvm-config-20 llvm-config-19 llvm-config; do
    command -v "$config" > /dev/null 2>&1 \
      && candidates+=("$("$config" --cmakedir 2>/dev/null || true)")
  done
  for version in 20 19; do
    candidates+=(/usr/lib64/llvm$version/lib/cmake/llvm
                 /usr/lib64/llvm$version/lib64/cmake/llvm
                 /usr/lib/llvm-$version/lib/cmake/llvm
                 /usr/lib/llvm$version/lib/cmake/llvm)
  done
  candidates+=(/usr/lib64/cmake/llvm /usr/lib/cmake/llvm /usr/local/lib/cmake/llvm)
  for dir in "${candidates[@]}"; do
    [[ -n "$dir" && -f "$dir/LLVMConfig.cmake" ]] || continue
    [[ "$(llvm_version "$dir")" =~ ^(19|20)\. ]] || continue
    echo "$dir"
    return 0
  done
  return 1
}

if [[ "${SRZGS_SKIP_DOLRECOMP:-0}" != "1" ]]; then
  DR_LLVM=(-DDOLRECOMP_ENABLE_LLVM=OFF)
  if [[ -n "${SRZGS_LLVM_DIR:-}" && ! -f "${SRZGS_LLVM_DIR}/LLVMConfig.cmake" ]]; then
    die "SRZGS_LLVM_DIR has no LLVMConfig.cmake: $SRZGS_LLVM_DIR"
  fi
  if [[ "${SRZGS_LLVM:-1}" != "0" ]]; then
    if LLVM_DIR_FOUND="$(find_llvm)"; then
      DR_LLVM=(-DDOLRECOMP_ENABLE_LLVM=ON "-DLLVM_DIR=$LLVM_DIR_FOUND")
      echo "LLVM $(llvm_version "$LLVM_DIR_FOUND"): $LLVM_DIR_FOUND (DolRecomp gets its LLVM backend)"
    else
      echo "LLVM 19 or 20 not found: DolRecomp is built with the C backend only."
      echo "  For the LLVM backend (Fedora): sudo dnf install llvm20-devel   then run this again"
    fi
  fi
  cmake -S "$DR_SRC" -B "$ROOT/build/dolrecomp" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF "${DR_LLVM[@]}"
  cmake --build "$ROOT/build/dolrecomp" --target dolrecomp -j"$JOBS"
  echo "DolRecomp: $ROOT/build/dolrecomp/dolrecomp"
fi

if [[ "${1:-}" == "--chassis" ]]; then
  [[ -f "$MG/vendor/dolphin/Externals/SDL/SDL/CMakeLists.txt" ]] \
    || die "ModernGekko submodules are incomplete: git submodule update --init --recursive"
  if [[ "$(uname -s)" == "Linux" ]]; then
    "$ROOT/tools/check_chassis_deps.sh" || exit 1
  fi

  # The launcher shows this version and compares it with the newest release
  # published on GitHub: the one in project(SR_SOURCE VERSION ...) of CMakeLists.txt.
  SRZGS_VERSION="$(awk '/^project\(SR_SOURCE/ {found=1} found && $1 == "VERSION" {print $2; exit}' \
    "$ROOT/CMakeLists.txt")"
  [[ "$SRZGS_VERSION" =~ ^[0-9]+(\.[0-9]+){0,3}$ ]] \
    || die "can't read the version from project(SR_SOURCE VERSION ...) in CMakeLists.txt"

  # Sys/GameSettings/GXEE8P.ini and RS9E8P.ini: each game's StaticRecomp
  # settings (see the files); Sonic Riders' replaces the one of ModernGekko's
  # Dolphin. JIT64 doesn't read them.
  # The Netplay lobby has no portrait beside it, and 16:9 and 4:3 fill the
  # window, so there are no bars for 4:3 borders: MODERNGEKKO_LOBBY_ART and
  # MODERNGEKKO_GAME_BORDERS are passed empty so a build folder made before
  # forgets the ones it had.
  echo "Building the chassis with $JOBS jobs. This compiles Dolphin's core: expect a long build."
  cmake -S "$MG" -B "$ROOT/build/chassis" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DDOLRECOMP_ENABLE_LLVM=OFF \
        ${CHASSIS_CMAKE_ARGS:-} \
        -DMODERNGEKKO_FRONTEND_NAME="Sonic Riders: Source" \
        -DMODERNGEKKO_LAUNCHER_TITLE="Riders Terminal" \
        -DMODERNGEKKO_PUBLISHER="KnivesDevilish" \
        -DMODERNGEKKO_LAUNCHER_OUTPUT_NAME="SR-Source" \
        -DMODERNGEKKO_REQUIRED_DISC_ID="RS9E8P" \
        -DMODERNGEKKO_GAMES="RS9E8P=Sonic Riders: Zero Gravity;GXEE8P=Sonic Riders" \
        -DMODERNGEKKO_DEFAULT_WINDOW_TITLE="Sonic Riders: Source" \
        -DMODERNGEKKO_USER_DIRECTORY_NAME="sr-source" \
        -DMODERNGEKKO_PREVIOUS_USER_DIRECTORY_NAMES="sr-zgs" \
        -DMODERNGEKKO_LAUNCHER_BANNER="$ROOT/docs/SR-Source Artwork.png" \
        -DMODERNGEKKO_LAUNCHER_BANNER_LAYERS="$ROOT/docs/banner" \
        -DMODERNGEKKO_LAUNCHER_CONTROLLER_ART="$ROOT/docs/SR-Source Controller.png" \
        -DMODERNGEKKO_LAUNCHER_KEYBOARD_ART="$ROOT/docs/SR-Source Keyboard.png" \
        -DMODERNGEKKO_LAUNCHER_MODS_ART="$ROOT/docs/SR-Source Mods.png" \
        -DMODERNGEKKO_LOBBY_ART="" \
        -DMODERNGEKKO_LAUNCHER_BACKGROUND="$ROOT/docs/SR-Source Background.png" \
        -DMODERNGEKKO_LAUNCHER_MUSIC="$ROOT/docs/SR-Source Launcher Track.mp3" \
        -DMODERNGEKKO_LOBBY_MUSIC="$ROOT/docs/SR-Source NetworkBattle Track.mp3" \
        -DMODERNGEKKO_LOBBY_BACKGROUND="$ROOT/docs/SR-Source Netplay Background.png" \
        -DMODERNGEKKO_APP_ICON="$ROOT/docs/SR-Source Icon.png" \
        -DMODERNGEKKO_APP_ICON_ICO="$ROOT/docs/SR-Source Icon.ico" \
        -DMODERNGEKKO_LAUNCHER_PATCH_NOTES="$ROOT/docs/SR-Source Patch Notes.txt" \
        -DMODERNGEKKO_GAME_BORDERS="" \
        -DMODERNGEKKO_COMPLETE_SAVE="$ROOT/docs/complete-save" \
        -DMODERNGEKKO_GAME_SELECT="$ROOT/docs/game-select" \
        -DMODERNGEKKO_GAME_SETTINGS_OVERRIDE="$ROOT/docs/game-settings/GXEE8P.ini;$ROOT/docs/game-settings/RS9E8P.ini" \
        -DMODERNGEKKO_SCREENSHOT_NAME="SR-Source" \
        -DMODERNGEKKO_FRONTEND_VERSION="$SRZGS_VERSION" \
        -DMODERNGEKKO_UPDATE_REPOSITORY="KnivesDevilish/SR-Source" \
        -DMODERNGEKKO_GAMECUBE_CONTROLLERS=ON \
        -DMODERNGEKKO_SAVESTATES=OFF \
        -DMODERNGEKKO_WINDOW_MENU=OFF

  cmake --build "$ROOT/build/chassis" \
        --target moderngekko-run moderngekko-launcher -j"$JOBS"

  RUNNER="$(find "$ROOT/build/chassis" -type f \
    -name "moderngekko-run$EXE" "${EXECUTABLE[@]}" -print -quit)"

  [[ -n "$RUNNER" ]] || die "build finished but moderngekko-run is missing"

  RUNNER_DIR="$(dirname "$RUNNER")"
  [[ -d "$RUNNER_DIR/Sys" ]] || die "Sys/ was not copied next to the runner"

  LAUNCHER="$(find "$ROOT/build/chassis" -type f \
    -name "SR-Source$EXE" "${EXECUTABLE[@]}" -print -quit)"

  [[ -n "$LAUNCHER" ]] || die "build finished but SR-Source launcher is missing"

  echo "Runner:    $RUNNER"
  echo "Launcher:  $LAUNCHER (version $SRZGS_VERSION)"
  echo "Next:      cmake --preset quick && cmake --build --preset quick --target srzgs_preflight"
fi
