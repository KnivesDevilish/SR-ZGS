# SR-ZGS — Testing Documentation

This document records the hardware, software, build environment, dependency revisions, graphics configuration and testing results used during SR-ZGS development.

Its purpose is to provide a reference configuration for future compatibility testing and performance comparisons. Values that have not been independently recorded are identified as such rather than estimated.

---

## 1. Test Environment — Dell Inspiron 3558

**Test Status:** Successfully tested  
**Test Platform:** Linux  
**Graphics Protocol:** Wayland  
**System Architecture:** x86_64  
**Test Date:** Not recorded

### Hardware Specifications

| Component | Specification |
|---|---|
| Manufacturer | Dell Inc. |
| Model | Inspiron 3558 |
| CPU | Intel Core i5-5200U @ 2.20 GHz |
| CPU Threads | 4 |
| GPU | Intel HD Graphics 5500 |
| System Memory | 16 GiB (15.5 GiB usable) |
| Architecture | 64-bit |

### Host Software Environment

| Component | Version |
|---|---|
| Operating System | Bazzite 44 |
| Desktop Environment | KDE Plasma 6.7.5 |
| KDE Frameworks | 6.30.0 |
| Qt | 6.11.2 |
| Linux Kernel | 7.2.4-ogc3.1.fc44.x86_64 |
| Display Protocol | Wayland |
| Host Display Resolution | 1920 × 1080 |

---

## 2. Build Environment

SR-ZGS is compiled inside a Distrobox container named `my-distrobox`. The game is run and tested on the Bazzite host system.

The container provides the development toolchain separately from the host operating system.

### Development Toolchain

| Component | Version / Configuration |
|---|---|
| Development Environment | Distrobox |
| Container Name | `my-distrobox` |
| GCC | 16.2.1 |
| C Compiler | GCC 16.2.1 (`/usr/bin/cc`) |
| C++ Compiler | GCC 16.2.1 (`/usr/bin/c++`) |
| CMake | 4.3.0 |
| Ninja | 1.13.2 |
| Build Generator | Ninja |
| Clang | Not found in the container environment |
| Main Project C++ Standard | C++20 |

### Build Configuration

| Component | Configuration |
|---|---|
| DolRecomp Build Type | Release |
| ModernGekko Build Type | Release |
| Tested Game Build Directory | `build/game-quick/` |
| Tested Game Build Configuration | Quick |
| Build Generator | Ninja |
| Main Project C++ Standard | C++20 |

CMake and Ninja are installed inside the Distrobox container, not on the Bazzite host system.

---

## 3. Dependency Versions

The following Git revisions were present in the tested development environment when the dependency status was inspected.

| Component | Repository Location | Commit Hash |
|---|---|---|
| ModernGekko | `external/ModernGekko/` | `a2e4e2b026a68d4848f20ebf16f0e0ddeb573957` |
| Dolphin (ModernGekko fork) | `external/ModernGekko/vendor/dolphin/` | `cf8ceb81b47d6172164cd0572f57aa7624719f33` |
| DolRecomp | `external/ModernGekko/vendor/dolphin/DolRecomp/` | `71ce7f97419b1bb1ba9a9596c41507f6629e0fb0` |

### Dependency Integration

DolRecomp is included as a nested Git submodule inside the Dolphin dependency bundled with ModernGekko.

The SR-ZGS build script compiles DolRecomp directly from:

```text
external/ModernGekko/vendor/dolphin/DolRecomp/
```

This keeps the recompilation toolchain aligned with the Dolphin revision pinned by ModernGekko, helping maintain compatibility with the runtime module ABI.

The listed submodules were initialized at the recorded revisions during the dependency inspection.

---

## 4. Test Results

The following results were observed during developer testing on the Dell Inspiron 3558.

| Test | Result |
|---|---|
| Game Initialization | Successful |
| Game Execution | Successful |
| Full Game Completion | Successful using JIT64 |
| JIT64 Performance | 60 FPS |
| StaticRecomp Execution | Successfully launched |
| StaticRecomp Performance | Significantly slower than JIT64 |

### Performance Notes

The 60 FPS result was achieved using ModernGekko's JIT64 CPU core with the following environment variable:

```bash
MODERNGEKKO_STATICRECOMP=0
```

This is an observed result from a specific hardware and software configuration, not a universal performance guarantee.

SR-ZGS also supports testing ModernGekko's StaticRecomp CPU execution path:

```bash
MODERNGEKKO_STATICRECOMP=1
```

StaticRecomp successfully launches the game but currently exhibits significantly lower performance on the reference hardware. An exact FPS measurement has not yet been recorded.

Both execution modes use the same ModernGekko-based runtime integration. The difference is the CPU execution core selected by ModernGekko.

Improving StaticRecomp execution performance is an ongoing development objective.

### CPU Execution Mode Comparison

Both CPU execution modes were tested using the same hardware and graphics configuration.

| Environment Variable | Selected CPU Core | Game Launch | Full Game Completion | Observed Performance |
|---|---|---|---|---|
| `MODERNGEKKO_STATICRECOMP=0` | JIT64 | Successful | Successful | 60 FPS |
| `MODERNGEKKO_STATICRECOMP=1` | StaticRecomp | Successful | Not verified | Significantly slower |

### Comparison Notes

**JIT64 Mode (`MODERNGEKKO_STATICRECOMP=0`)**
- Successfully launched and completed the game from start to finish.
- 60 FPS observed during developer testing.
- Currently serves as the reference performance configuration.

**StaticRecomp Mode (`MODERNGEKKO_STATICRECOMP=1`)**
- Successfully launched the game.
- Performance was significantly lower than JIT64.
- Full game completion has not yet been verified in this mode.
- Exact FPS measurements have not yet been recorded.

These results will serve as a baseline for future StaticRecomp performance optimization.

---

## 5. Graphics and Runtime Configuration

The following settings were copied from the configuration files provided for the developer test.

### Display Configuration

| Setting | Value |
|---|---|
| Host Display Resolution | 1920 × 1080 |
| SR-ZGS Configured Resolution | 640 × 528 |
| Graphics Backend | Vulkan |
| Fullscreen | Disabled |
| V-Sync | Disabled |

The host display resolution and the configured SR-ZGS resolution are separate values. The 640 × 528 value comes from the application's video configuration and should not be interpreted as the host monitor resolution.

### Graphics Settings

Source: Graphics configuration (`gfx` settings)

| Setting | Recorded Value |
|---|---|
| Internal Resolution | `1` |
| Shader Cache | `True` |
| Shader Compilation Mode | `2` |
| Wait for Shaders Before Starting | `True` |
| Aspect Ratio | `3` |
| Cache High-Resolution Textures | `True` |
| High-Resolution Textures | `True` |
| Texture Dumping | `False` |

Numeric configuration values are recorded exactly as provided. Their internal enum meanings have not been independently verified.

### Runtime Settings

Source: Dolphin runtime configuration

| Setting | Recorded Value |
|---|---|
| CPU Core (Dolphin configuration) | `1` (raw configuration value) |
| Graphics Backend | Vulkan |
| Fullscreen | `False` |
| DSP Backend | Pulse |
| DSP Thread | `False` |
| Background Input | `False` |

The effective CPU execution mode is selected by
`MODERNGEKKO_STATICRECOMP` in the ModernGekko runtime.

Machine-specific identifiers and analytics IDs are intentionally omitted because they are not needed to reproduce the graphics or performance configuration.

### Configuration Notes

- Vulkan was used as the graphics backend during the reported performance test.
- V-Sync was disabled.
- The application was configured to run in windowed mode.
- High-resolution texture support and shader caching were enabled in the recorded graphics settings.

This configuration represents the recorded developer testing environment and can be used as a reference when comparing future builds.

---

## 6. Known Limitations

- The project currently relies on ModernGekko for graphics, audio, input and Wii system-level functionality.
- An independent runtime has not yet been implemented.
- Windows compatibility has not yet been verified.
- Android support remains a long-term development goal.
- Performance results documented here apply only to the hardware and configuration listed in this report.

---

## 7. Future Testing

Future compatibility reports should be documented separately, including their hardware, software and dependency configurations.

Planned testing areas include:

- Linux compatibility with different desktop environments and display protocols.
- Windows compatibility.
- Different integrated and dedicated GPUs.
- Additional CPU and memory configurations.
- Performance consistency and frame-time measurements.
- Runtime compatibility following DolRecomp, Dolphin or ModernGekko updates.

Each new test should record the exact dependency revisions used so that performance changes and potential regressions can be compared reliably.

---

**Project:** Sonic Riders: Zero Gravity — Static Recompilation (SR-ZGS)  
**Primary Development Platform:** Bazzite Linux  
**Build Environment:** Distrobox (`my-distrobox`)  
**Current Runtime:** ModernGekko (Dolphin-derived)
