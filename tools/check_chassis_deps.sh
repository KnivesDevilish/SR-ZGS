#!/usr/bin/env bash
# =============================================================================
# SR:ZGS - check the system packages the ModernGekko chassis needs BEFORE a
# build that takes the better part of an hour. Derived from the chassis CMake:
#   * X11 input (xi >= 1.5) is a hard requirement once X11 is found.
#   * wayland-client enables the Wayland path, which then hard-requires
#     wayland-scanner, wayland-protocols, wayland-cursor and xkbcommon.
#   * ALSA and PulseAudio are OPTIONAL in CMake: with neither present the build
#     succeeds and the game is silently mute on Linux. Treated as required here.
# libudev/libevdev are only "recommended" (warning, never blocking).
# Exit status: 0 = all required present, 1 = something missing (list printed).
# =============================================================================
set -uo pipefail

missing=()
recommended=()
need_cmd() { command -v "$1" >/dev/null 2>&1 || missing+=("command: $1  ($2)"); }
need_pc()  { pkg-config --exists "$1" 2>/dev/null || missing+=("pkg-config: $1  ($2)"); }

need_cmd cmake       "cmake >= 3.22"
need_cmd ninja       "ninja-build / ninja"
need_cmd python3     "python3"
need_cmd git         "git"
need_cmd pkg-config  "pkg-config / pkgconf"
if ! command -v c++ >/dev/null 2>&1 && ! command -v clang++ >/dev/null 2>&1; then
  missing+=("command: c++ or clang++  (C++23-capable compiler: GCC 13+ or Clang 17+)")
fi

if command -v pkg-config >/dev/null 2>&1; then
  need_pc x11            "libx11-dev"
  need_pc xi             "libxi-dev (>= 1.5)"
  need_pc xrandr         "libxrandr-dev"
  need_pc wayland-client "libwayland-dev"
  need_pc wayland-cursor "libwayland-dev"
  need_pc xkbcommon      "libxkbcommon-dev"
  need_pc alsa           "libasound2-dev"
  need_pc libpulse       "libpulse-dev"
  need_pc gl             "libgl1-mesa-dev"
  # Not required by the chassis CMake (it forces evdev/hwdb off), but the
  # Dolphin CI package list includes them and SDL3 can use libudev.
  for opt in "libudev:libudev-dev" "libevdev:libevdev-dev"; do
    pkg-config --exists "${opt%%:*}" 2>/dev/null || recommended+=("${opt%%:*}  (${opt##*:})")
  done
fi
command -v wayland-scanner >/dev/null 2>&1 || missing+=("command: wayland-scanner  (libwayland-bin / wayland-devel)")
[[ -f /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml ]] \
  || missing+=("file: /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml  (wayland-protocols)")

if ((${#missing[@]})); then
  echo "Missing build requirements for the chassis:"
  printf '  - %s\n' "${missing[@]}"
  echo
  echo "Ubuntu/Debian:"
  echo "  sudo apt-get install -y build-essential cmake ninja-build pkg-config python3 git \\"
  echo "    libx11-dev libxi-dev libxrandr-dev libwayland-dev wayland-protocols libxkbcommon-dev \\"
  echo "    libasound2-dev libpulse-dev libgl1-mesa-dev libudev-dev libevdev-dev \\"
  echo "    libsystemd-dev libbluetooth-dev libgtk-3-dev"
  echo "Fedora (package names not verified by us):"
  echo "  sudo dnf install -y gcc-c++ cmake ninja-build pkgconf-pkg-config python3 git \\"
  echo "    libX11-devel libXi-devel libXrandr-devel wayland-devel wayland-protocols-devel \\"
  echo "    libxkbcommon-devel alsa-lib-devel pulseaudio-libs-devel mesa-libGL-devel \\"
  echo "    systemd-devel libevdev-devel bluez-libs-devel gtk3-devel"
  exit 1
fi
if ((${#recommended[@]})); then
  echo "Recommended, not blocking: ${recommended[*]}"
fi
echo "Chassis build requirements: OK"
