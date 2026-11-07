#!/usr/bin/env bash
# =============================================================================
# SR:ZGS - packs a release from the chassis build (tools/build_tools.sh
# --chassis): the launcher and the runner, their Sys/ and Resources/ folders,
# any shared libraries beside them, the licenses and a short read-me, into
#   dist/SR-ZGS-<version>-linux-<arch>.tar.gz     (Linux)
#   dist/SR-ZGS-<version>-windows-x64.zip         (Windows, in Git Bash)
# with a .sha256 file next to it.
#
# No game files go in: players extract their own copy of the game with the
# launcher. Nor does the StaticRecomp module (g<ID>_recomp.so/.dll), which is
# made from the game's own code; a release plays with JIT64.
#
#   tools/package_release.sh            # after tools/build_tools.sh --chassis
#   BUILD_DIR=/path/to/chassis tools/package_release.sh
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build/chassis}"
DIST="${DIST_DIR:-$ROOT/dist}"

die() { echo "error: $*" >&2; exit 1; }

VERSION="$(awk '/^project\(SR_ZGS/ {found=1} found && $1 == "VERSION" {print $2; exit}' \
  "$ROOT/CMakeLists.txt")"
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,3}$ ]] \
  || die "can't read the version from project(SR_ZGS VERSION ...) in CMakeLists.txt"

EXE=""
case "$(uname -s)" in
  Linux)
    ARCH="$(uname -m)"
    PLATFORM="linux-$ARCH"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    EXE=".exe"
    PLATFORM="windows-x64"
    ROOT="$(cygpath -m "$ROOT")"
    BUILD="${BUILD_DIR:-$ROOT/build/chassis}"
    DIST="${DIST_DIR:-$ROOT/dist}"
    ;;
  *)
    die "packing for $(uname -s) isn't supported"
    ;;
esac

[[ -d "$BUILD" ]] || die "no build in $BUILD: run tools/build_tools.sh --chassis first"

# The launcher starts the runner beside it, so both must be in one folder.
LAUNCHER="$(find "$BUILD" -type f -name "SR-ZGS$EXE" -print -quit)"
[[ -n "$LAUNCHER" ]] || die "SR-ZGS$EXE is missing in $BUILD"
BIN="$(dirname "$LAUNCHER")"
[[ -f "$BIN/moderngekko-run$EXE" ]] || die "moderngekko-run$EXE is missing beside $LAUNCHER"
[[ -d "$BIN/Sys" ]] || die "Sys/ is missing beside $LAUNCHER"
[[ -d "$BIN/Resources" ]] || die "Resources/ is missing beside $LAUNCHER"

NAME="SR-ZGS-$VERSION-$PLATFORM"
STAGE="$DIST/$NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE"

echo "Packing $NAME from $BIN"
cp "$LAUNCHER" "$BIN/moderngekko-run$EXE" "$STAGE/"
cp -R "$BIN/Sys" "$BIN/Resources" "$STAGE/"

# Shared libraries the build put beside the programs, but never a
# StaticRecomp module (made from the game's code) or a test library.
shopt -s nullglob
for library in "$BIN"/*.so "$BIN"/*.so.* "$BIN"/*.dll; do
  base="$(basename "$library")"
  case "$base" in
    g*_recomp*|*test_module*|*.mgm*) echo "  left out: $base" ;;
    *) cp "$library" "$STAGE/"; echo "  library: $base" ;;
  esac
done
shopt -u nullglob

# Windows: the Visual C++ runtime the programs need, beside them, so nothing
# has to be installed first. VCToolsRedistDir is set by the Visual Studio
# developer environment.
if [[ -n "$EXE" ]]; then
  if [[ -n "${VCToolsRedistDir:-}" ]]; then
    REDIST="$(cygpath -u "$VCToolsRedistDir" 2>/dev/null || echo "$VCToolsRedistDir")"
    CRT="$(find "$REDIST/x64" -maxdepth 1 -type d -name 'Microsoft.VC*.CRT' -print -quit 2>/dev/null || true)"
    if [[ -n "$CRT" ]]; then
      for dll in msvcp140.dll vcruntime140.dll vcruntime140_1.dll; do
        if [[ -f "$CRT/$dll" ]]; then
          cp "$CRT/$dll" "$STAGE/"
          echo "  runtime: $dll"
        fi
      done
    else
      echo "warning: no Microsoft.VC*.CRT folder in $REDIST/x64; the Visual C++ runtime isn't included" >&2
    fi
  else
    echo "warning: VCToolsRedistDir isn't set; the Visual C++ runtime isn't included" >&2
  fi
fi

# Nothing from the game may be in the package.
if find "$STAGE" \( -iname '*.iso' -o -iname '*.wbfs' -o -iname '*.rvz' -o -iname 'main.dol' \
     -o -iname 'boot.bin' -o -iname '*_recomp*' \) -print -quit | grep -q .; then
  die "game files found in $STAGE: they must not be released"
fi

cp "$ROOT/LICENSE" "$STAGE/LICENSE.txt"
cp "$ROOT/docs/SR-ZGS Patch Notes.txt" "$STAGE/PATCH-NOTES.txt"

if [[ -n "$EXE" ]]; then
  START='Double-click SR-ZGS.exe.'
  START_ES='Abre SR-ZGS.exe con doble clic.'
  USER_DIR='%LOCALAPPDATA%\sr-zgs'
else
  START='Run ./SR-ZGS from this folder (or double-click SR-ZGS in your file manager).'
  START_ES='Ejecuta ./SR-ZGS desde esta carpeta (o abre SR-ZGS con doble clic en tu gestor de archivos).'
  USER_DIR='~/.local/share/sr-zgs'
fi
cat > "$STAGE/README.txt" <<EOF
Sonic Riders: Zero Gravity Source (SR-ZGS) $VERSION

SR-ZGS needs your own legally obtained copy of Sonic Riders: Zero Gravity for
Wii (NTSC-U, RS9E8P) as an ISO, WBFS or RVZ image. No game files are included.

1. $START
2. Open Game Files, choose your disc image and press Extract Game (only once).
3. Press PLAY.

Keep this folder's files together: SR-ZGS starts moderngekko-run beside it.
Your settings, saves, screenshots and logs are in $USER_DIR.
The CPU core is JIT64; StaticRecomp needs a build from source.

Source code (GNU GPL v3): https://github.com/KnivesDevilish/SR-ZGS
(tag v$VERSION, with the ModernGekko fork in external/ModernGekko).
More: https://github.com/KnivesDevilish/SR-ZGS#readme

---

SR-ZGS necesita tu propia copia legal de Sonic Riders: Zero Gravity para Wii
(NTSC-U, RS9E8P) en imagen ISO, WBFS o RVZ. No incluye archivos del juego.

1. $START_ES
2. Abre Archivos del juego, elige tu imagen del disco y pulsa Extraer juego
   (solo la primera vez).
3. Pulsa JUGAR.

Deja juntos los archivos de esta carpeta: SR-ZGS abre moderngekko-run, que
está a su lado. Tus ajustes, partidas, capturas y registros están en
$USER_DIR.
El núcleo de CPU es JIT64; StaticRecomp necesita compilarlo desde el código.

This project is an independent fan project and is not affiliated with or
endorsed by SEGA. Sonic Riders: Zero Gravity and its characters are
trademarks of SEGA.
EOF

cd "$DIST"
if [[ -n "$EXE" ]]; then
  ARCHIVE="$NAME.zip"
  rm -f "$ARCHIVE"
  if command -v 7z >/dev/null 2>&1; then
    7z a -tzip -bso0 "$ARCHIVE" "$NAME" >/dev/null
  elif command -v zip >/dev/null 2>&1; then
    zip -qr "$ARCHIVE" "$NAME"
  else
    powershell -NoProfile -Command "Compress-Archive -Path '$NAME' -DestinationPath '$ARCHIVE'"
  fi
else
  ARCHIVE="$NAME.tar.gz"
  tar -czf "$ARCHIVE" "$NAME"
fi
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
echo "Release:   $DIST/$ARCHIVE"
echo "Checksum:  $(cut -d' ' -f1 "$ARCHIVE.sha256")"
