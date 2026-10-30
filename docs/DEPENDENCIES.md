# SR-ZGS — Dependencies

| Field | Value |
|---|---|
| Document version | 1.2 (Phase 0 closure synchronization) |
| Date | 2026-10-30 |
| Status | Dependencies **identified**; pin set **approved**. Not yet added to the SR-ZGS repository as submodules. Nothing installed or built for SR-ZGS. |
| Pin decision (D1) | Option B **APPROVED** (developer, 2026-10-30) |

Evidence labels are defined in `PROJECT_OVERVIEW.md` §1.

---

## 1. Upstream repositories inspected (VERIFIED)

| Repository | Commit | Date | Notes |
|---|---|---|---|
| `https://github.com/ExpansionPak/ModernGekko-Template` (`main`) | `c2553a99584b2045dbe46a70e1570994dae8beef` | 2026-09-16 | 30 commits; first commit 2026-07-13 |
| `https://github.com/ExpansionPak/ModernGekko` (`master`) | `a2e4e2b026a68d4848f20ebf16f0e0ddeb573957` | 2026-09-16 | 81 commits |
| ModernGekko (the template's pin) | `edd460adad0e82b56909af1d793642c83b6d31c8` | 2026-09-16 | — |
| `https://github.com/ExpansionPak/RecompCore`, branch `moderngekko-vendor` | `cf8ceb81b47d6172164cd0572f57aa7624719f33` | 2026-09-16 | ModernGekko master's `vendor/dolphin` pin; shallow and partial inspection |
| RecompCore (pinned by ModernGekko `edd460a`) | `10f7ac4fe48f74485fbc161ebf4d67242e11e671` | 2026-09-16 | Differs from `cf8ceb8` only in its DolRecomp pin |
| `https://github.com/ExpansionPak/DolRecomp` (`main` HEAD) | `02e27aca1c408cfcb2a4079a3a5b5ab3ae39d340` | 2026-10-10 | 164 commits |
| DolRecomp (pinned by RecompCore `cf8ceb8`) | `71ce7f97419b1bb1ba9a9596c41507f6629e0fb0` | 2026-09-16 | — |
| DolRecomp (pinned by the template and by RecompCore `10f7ac4`) | `1bec3554ecc4817cf78319ca3d8a0669477f29fa` | 2026-08-23 | — |

**Re-check, 2026-10-30 (Phase 0 closure).**
- A read-only `git ls-remote` showed the default-branch heads of ModernGekko (`a2e4e2b`), DolRecomp (`02e27ac`) and ModernGekko-Template (`c2553a9`), and RecompCore's `moderngekko-vendor` branch (`cf8ceb8`), unchanged from this table. RecompCore's default branch is at `78bdce8`; it is not part of the pin set.
- The pin chain was confirmed from the gitlinks in the local audit clones: ModernGekko `a2e4e2b` `vendor/dolphin` → `cf8ceb8`; RecompCore `cf8ceb8` `DolRecomp` → `71ce7f9`; ModernGekko-Template `c2553a9` `lib/ModernGekko` → `edd460a` and `lib/DolRecomp` → `1bec355`.

---

## 2. Pin sets (D1)

| Set | Template-level `lib/ModernGekko` | RecompCore (`vendor/dolphin`) | Nested DolRecomp (the one that recompiles) | External `lib/DolRecomp` | Status |
|---|---|---|---|---|---|
| **Option B** | `a2e4e2b` | `cf8ceb8` | `71ce7f9` | **Align to `71ce7f9`** | **APPROVED** (D1, 2026-10-30) |
| Option A | `edd460a` | `10f7ac4` | `1bec355` | `1bec355` (template default) | Not adopted |
| DolRecomp HEAD | — | — | `02e27ac` | — | Not adopted: no runtime pins it, and its documented native-module mode has no consumer |

**ModernGekko-Template.** Revision `c2553a9` is the approved **architectural reference**. Its own submodule pins (Option A: ModernGekko `edd460a`, DolRecomp `1bec355`) are **not** adopted.

**Why Option B was chosen.**
- It is the maintainers' latest coherent set: ModernGekko's own commit "Repin vendored DolRecomp".
- It includes DolRecomp correctness fixes, such as "Make the instruction after an MSR write a region leader".
- Compatibility with the available toolchain is equally untested for A and B.

**Alignment rule.** In the template, `lib/DolRecomp` is used only for `--setup` and `extract`, while recompilation uses the nested copy. The two must point to the same commit, or one source of truth must be chosen. Dropping `lib/DolRecomp` is a Phase 1 option to evaluate.

---

## 3. Submodule structure (VERIFIED)

- **Template:** `lib/DolRecomp` and `lib/ModernGekko`.
- **ModernGekko:** `vendor/dolphin` → `https://github.com/ExpansionPak/RecompCore.git`, branch `moderngekko-vendor`, `shallow = true`.
  - Vendored in-tree (not submodules): `vendor/dolphin_legacy`, `vendor/fmt`, `vendor/picojson`.
- **RecompCore `.gitmodules`: 35 shallow submodules.**
  - DolRecomp: `https://github.com/ExpansionPak/DolRecomp.git`.
  - SDL, fmt, imgui, implot, glslang, SPIRV-Cross, Vulkan-Headers, VulkanMemoryAllocator.
  - zstd, lz4, xxHash, zlib-ng, minizip-ng, bzip2 (hosted on gitlab.com), libspng.
  - cubeb, curl, enet, hidapi, libusb, pugixml, tinygltf, watcher, SFML, miniupnp, rcheevos, cpp-ipc, cpp-optparse, gtest, mGBA.
  - Platform-specific, not needed on Linux (TI from project purpose): `ext-win-qt`, `ext-win-ffmpeg` and `wil` (Windows); `libadrenotools` (Android).
  - A full recursive checkout pulls all of them, "a few hundred MB" according to the template README.

---

## 4. Toolchain requirements (from source)

| Requirement | Version requirement | Evidence | Build / run time |
|---|---|---|---|
| CMake | Minimum 3.20 for ModernGekko and the template check; minimum 3.16 for DolRecomp. RecompCore declares `cmake_minimum_required(VERSION 3.20...4.2.1)` (see the note below this table). CMake 4.3.0 compatibility: **NOT TESTED**. | `cmake_minimum_required` calls (VERIFIED) | Build |
| Ninja | Not stated | `-G Ninja` throughout (VERIFIED) | Build |
| GNU Make | Not stated | Template Makefile | Build |
| C compiler | C11 | DolRecomp, template check (VERIFIED) | Build |
| C++ compiler | C++23 for ModernGekko and RecompCore; C++17 for DolRecomp's LLVM backend | `CMAKE_CXX_STANDARD` (VERIFIED). **Minimum GCC/Clang versions not stated (UNK).** | Build |
| 64-bit target, 8-byte pointers | Required | `scripts/compiler-check` (VERIFIED) | Build |
| Python 3 | Not stated | `module-template/CMakeLists.txt:40`, `find_package(Python3 REQUIRED)` (VERIFIED) | Build (per-game module) |
| Git with submodule support | Not stated | Template | Build |
| pkg-config | Not stated | `pkg_check_modules` (VERIFIED) | Build |
| **LLVM development files** (`LLVMConfig.cmake`, X86 target) | **`19 <= version < 21`** | DolRecomp `CMakeLists.txt:10-16` (VERIFIED); CI uses LLVM 20 | Build only; no runtime dependency (README) |
| Clang + matching `llvm-profdata` | Matching major versions | `moderngekko_port.cpp` `pgo-run` | Optional (PGO, Phase 6) |
| LLD | — | Appears only in an identity string in `moderngekko_port.cpp`, not passed to the build (SC) | Not required by the module build (TI) |
| zlib | — | DolRecomp CMake | Optional (Wii U RPX only) |

**Reading `cmake_minimum_required(VERSION 3.20...4.2.1)`:**
- `3.20` is the **minimum required** CMake version.
- `4.2.1` is the **maximum policy version** the project requests. It controls which CMake policy behaviors apply; it is **not** an upper limit on the CMake version.
- The syntax therefore does **not** prohibit running newer releases such as CMake 4.3.0.
- It also does **not** prove that CMake 4.3.0 configures or builds the project successfully.
- Compatibility with CMake 4.3.0 remains **NOT TESTED**.

---

## 5. Known discrepancies in upstream metadata (VERIFIED)

1. **Stale revision labels.** `tools/moderngekko_port.cpp:35-37` hard-codes `RECOMPCORE_REVISION=55c7b023…` and `DOLRECOMP_REVISION=1bec3554…` at both `edd460a` and `a2e4e2b`. Neither matches master's actual pins. They are labels in the module cache key only; the key also includes the SHA-256 of the `dolrecomp` binary.
2. **PROVENANCE vs `.gitmodules`.** `ModernGekko/PROVENANCE.md` names `RecompCore-ModernGekko.git` at `8b47e90` on branch `main`. `.gitmodules` uses `RecompCore.git` on branch `moderngekko-vendor`, pinned at `cf8ceb8`. The submodule pin is authoritative for what actually builds.
3. **Stale module-template README.** `RecompCore/module-template/README.md` references `aharonahdoot/DolRecomp`, an "interpreter fallback", a `StrikersRecomp` fix-up script, and `-C Dolphin.Core.CPUCore=6`.
4. **Template dependency list.** The template's Linux dependency list is Ubuntu `apt` only. It includes `libevdev`, `libudev`, GTK3, `libsystemd` and `bluez`, which appear unnecessary given the options ModernGekko forces (TI).

---

## 6. Build-time library dependencies (SC)

ModernGekko forces these Dolphin options (`ModernGekko/CMakeLists.txt`, around lines 90-125):

| Forced setting | Options |
|---|---|
| OFF | `ENABLE_QT`, `ENABLE_NOGUI`, `ENABLE_AUTOUPDATE`, `ENABLE_ANALYTICS`, `USE_RETRO_ACHIEVEMENTS`, `USE_DISCORD_PRESENCE`, `USE_MGBA`, `USE_UPNP`, `ENCODE_FRAMEDUMPS`, `ENABLE_LLVM` (Dolphin's own disassembler), `ENABLE_HWDB`, `ENABLE_EVDEV`, `ENABLE_EGL`, `USE_SYSTEM_SDL3` |
| OFF on Linux | `ENABLE_CUBEB` |
| ON | `ENABLE_WAYLAND`, `LINUX_LOCAL_DEV` |
| Follows `MODERNGEKKO_ENABLE_DISC_TOOL` | `ENABLE_CLI_TOOL` |

The Fedora package names below are **candidates to confirm** in Phase 1.

| Library / tool | Condition | Evidence | Candidate Fedora package |
|---|---|---|---|
| `wayland-client` | Detected; Wayland support compiled if found | RecompCore `CMakeLists.txt` | `wayland-devel` |
| `wayland-scanner`; `xdg-shell.xml`, `xdg-decoration-unstable-v1.xml`, `idle-inhibit-unstable-v1.xml`; `wayland-cursor`; `xkbcommon` | **Required** once `wayland-client` is found | ModernGekko `CMakeLists.txt` (`REQUIRED` lookups) | `wayland-devel`, `wayland-protocols-devel`, `libxkbcommon-devel` |
| `x11`, `xrandr`; `xi >= 1.5.0` | X11 support (`ENABLE_X11` ON by default); `xi` **required** if `x11` is found | RecompCore `CMakeLists.txt:512-521` | `libX11-devel`, `libXrandr-devel`, `libXi-devel` |
| OpenGL (GLVND) | `find_package(OpenGL)` | RecompCore `CMakeLists.txt:495-500` | `mesa-libGL-devel` / `libglvnd-devel` |
| ALSA, PulseAudio | `ENABLE_ALSA` and `ENABLE_PULSEAUDIO` ON; **without the headers, the build silently has no audio backend** | RecompCore `CMakeLists.txt:91-92`; `AudioCommon/CMakeLists.txt` | `alsa-lib-devel`, `pulseaudio-libs-devel` |
| Vulkan headers | Bundled submodule `Externals/Vulkan-Headers`; `vulkan.pc` not required by the inspected lookups | RecompCore `.gitmodules` | — |
| SDL3 | Bundled (`USE_SYSTEM_SDL3=OFF`) | ModernGekko `CMakeLists.txt` | — |

---

## 7. Runtime dependencies (SC; NOT TESTED)

- Mesa userspace drivers (Vulkan and OpenGL) and the Vulkan loader (`libvulkan.so.1`). That Dolphin's Vulkan backend loads the loader dynamically is TI; the loader code was not inspected.
- `libwayland-client`, `libwayland-cursor`, `libxkbcommon` and/or the X11 libraries, matching the platforms compiled in.
- A PulseAudio-compatible server (PipeWire's PulseAudio service on the host) or ALSA.
- Controller configuration INI files in the ModernGekko user directory (none are created automatically).
- LLVM is **not** a runtime dependency.

---

## 8. External tools and data fetched by upstream tooling (SC)

| Item | Fetched by | When | Integrity check | SR-ZGS policy |
|---|---|---|---|---|
| `wit-v3.05a-r8638-x86_64.tar.gz` from `wit.wiimm.de` | `dolrecomp --setup` (`setup.c:26`), run as `echo y \| …` by template `Makefile:121` | Template extraction path | **None** | Only with explicit approval and a pinned checksum (D3) |
| GameTDB `titles.txt` (`https://www.gametdb.com/titles.txt?LANG=EN`) | `dolrecomp --setup` (`database.c`), via `curl` | Same | None | Optional; affects naming only (TI) |
| Redump datfile | Dolphin `VolumeVerifier` | **Disabled** in `dolphin-tool verify` (`redump_verification=false`) | — | Not used |
| Submodules | `git submodule update --init --recursive` | Dependency fetch | Commit pins | Allowed in Phase 1, subject to approval |

---

## 9. LLVM status

| Fact | Label |
|---|---|
| DolRecomp accepts only `19 <= LLVM < 21` | VERIFIED |
| DolRecomp CI uses LLVM 20 (20.1.8 for the Windows jobs, Homebrew `llvm@20` on macOS, apt.llvm.org `llvm-20-dev` on Ubuntu) | VERIFIED (CI definition at `71ce7f9`) |
| Fedora 44 default `llvm-devel` is `22.1.8-4.fc44`, outside the accepted range | Fedora package database (checked 2026-10-30) |
| Fedora 44 offers `llvm20-devel` `20.1.8-9.fc44` (fedora-44-updates) | Fedora package database |
| `llvm19-devel` is listed for Fedora 44 | Fedora package database (version not recorded) |
| `llvm20-libs` installs under `/usr/lib64/llvm20/lib64/`, which suggests `LLVM_DIR=/usr/lib64/llvm20/lib64/cmake/llvm` | Package database file list; the path itself is TI |
| LLVM 19/20 installed on the host | **No** (UPE) |
| LLVM 19/20 installed in the existing Toolbx container | **No** (UPE) |
| Whether Fedora's `llvm20-devel` provides a shared `LLVM` target or only component libraries | UNK |
| DolRecomp LLVM backend configured or compiled | **NOT TESTED** |

"Available in Fedora's package database" does **not** mean installed. Installed will not mean build-tested: a successful configure and build must be executed and recorded separately.

---

## 10. Observed tool versions (UPE)

| Tool | Host (Bazzite 44) | Existing Fedora 44 Toolbx container |
|---|---|---|
| GCC / G++ | 16.2.1 | 16.2.1 |
| CMake | not found | 4.3.0 |
| Ninja | not found | 1.13.2 |
| Make | 4.4.1 | 4.4.1 |
| Git | 2.55.0 | 2.56.0 |
| Python | 3.14.7 | 3.14.8 |
| pkg-config | 2.5.1 | present |
| wayland-scanner | not found | 1.26.0 |
| Clang / Clang++ | not found | not found |
| `llvm-config`, `llvm-config-19`, `llvm-config-20` | not found | not found |
| LLD | not found | not found |
| Wayland, xkbcommon, X11/Xi/Xrandr, GL/EGL, ALSA, PulseAudio development files | — | present (`pkg-config` resolves them) |
| `pkg-config vulkan` | — | not found (loader development package absent; runtime loader present) |

The existing Toolbx container is **not** the canonical build environment (see `BUILD_ENVIRONMENT.md` §5).

---

## 11. Compatibility caveats

- GCC 16.2.1, CMake 4.3.0 and Python 3.14.x are newer than anything upstream CI uses. Compatibility is **NOT TESTED**.
- CMake 4 readiness:
  - **What the wrappers declare (SC).** RecompCore's own `Externals/*/CMakeLists.txt` wrapper files at `cf8ceb8` declare one of two forms:
    - a plain minimum of 3.13 or higher, or
    - a `<minimum>...<policy-max>` form whose maximum policy version is 4.1.1 or 4.2.0, for example `2.8.12...4.1.1` (mbedtls) or `3.13...4.2.0` (zstd).
  - **What that implies (TI).** CMake 4 removed compatibility with policy versions below 3.5. These declarations should therefore not trip that removal. This is TI from CMake's documented semantics, not a tested result.
  - **Not inspected (UNK).** The build files inside the bundled submodules themselves.
- ModernGekko CI builds only the C backend. The LLVM path is not CI-built there (VERIFIED).
- A recursive shallow clone of the pinned commits has **NOT been tested**.
- Toolchain parallelism: `moderngekko-port` runs `dolrecomp` and the module build with the full hardware thread count (4 on the host). Memory use is unmeasured.

---

## 12. Reproducibility policy

These are rules for Phase 1 onward; none is implemented yet.

1. Record every submodule commit, including the output of `git submodule status --recursive`, in this document.
2. Never use `git submodule update --remote` for pinned dependencies.
3. Pin the build-environment base image **by digest**, and record a full `rpm -qa` package list after provisioning.
4. Keep each generated module's `manifest.txt` alongside its build log.
5. Record compiler, CMake, Ninja, Python and LLVM versions for every build.
6. Document every local patch to an upstream dependency, keep it isolated, and avoid patches unless strictly necessary.
7. Treat a clean, fresh recursive clone followed by a successful configure as the reproducibility test.

---

## 13. Licenses (VERIFIED as stated upstream)

| Component | License |
|---|---|
| ModernGekko | GPL-3.0-or-later, because of its Dolphin-derived runtime (`LICENSE`, `PROVENANCE.md`) |
| RecompCore / Dolphin | Mostly GPL-2.0-or-later, in a combined tree described as GPLv3-compatible. Per-file SPDX identifiers and `LICENSES/` are authoritative (`PROVENANCE.md`). |
| DolRecomp | GPLv3 (as described in ModernGekko's `PROVENANCE.md`; DolRecomp's own `LICENSE` to be reviewed in Phase 9) |
| Bundled submodules | Their own licenses; to be reviewed in Phase 9 |
| SR-ZGS-owned code | GPL-3.0 (D4, approved 2026-10-30); see the repository's `LICENSE` |

---

## 14. Sources

- ModernGekko-Template: <https://github.com/ExpansionPak/ModernGekko-Template>
- ModernGekko: <https://github.com/ExpansionPak/ModernGekko>
- RecompCore: <https://github.com/ExpansionPak/RecompCore>
- DolRecomp: <https://github.com/ExpansionPak/DolRecomp>
- Fedora `llvm-devel` (F44 updates): <https://packages.fedoraproject.org/pkgs/llvm/llvm-devel/fedora-44-updates.html>
- Fedora `llvm20-devel`: <https://packages.fedoraproject.org/pkgs/llvm20/llvm20-devel/>
- Fedora `llvm20-libs` (F44 updates): <https://packages.fedoraproject.org/pkgs/llvm20/llvm20-libs/fedora-44-updates.html>
- Fedora `llvm19-devel` (F44): <https://packages.fedoraproject.org/pkgs/llvm19/llvm19-devel/fedora-44.html>
