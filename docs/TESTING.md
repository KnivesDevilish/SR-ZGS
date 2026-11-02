# SR-ZGS — Testing Documentation

This document records the hardware, software, build environment, dependency revisions and testing results used during SR-ZGS development.

Its purpose is to provide a reproducible reference configuration for future compatibility testing and performance comparisons.

---

## 1. Test Environment — Dell Inspiron 3558

**Test Status:** Successfully tested  
**Test Platform:** Linux  
**Graphics Protocol:** Wayland  
**System Architecture:** x86_64

### Hardware Specifications

| Component | Specification |
|---|---|
| Manufacturer | Dell Inc. |
| Model | Inspiron 3558 |
| CPU | Intel Core i5-5200U @ 2.20 GHz |
| Logical Processors | 4 |
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

---

## 2. Build Environment

SR-ZGS is compiled inside a Distrobox container named `my-distrobox`.

The container provides the development toolchain separately from the Bazzite host system.

### Development Toolchain

| Component | Version |
|---|---|
| Development Environment | Distrobox |
| Container Name | `my-distrobox` |
| GCC | 16.2.1 |
| C Compiler | GCC 16.2.1 |
| C++ Compiler | GCC 16.2.1 |
| CMake | 4.3.0 |
| Ninja | 1.13.2 |
| Build Generator | Ninja |
| Clang | Not installed |

### Build Configuration

| Component | Configuration |
|---|---|
| DolRecomp Build Type | Release |
| ModernGekko Build Type | Release |
| Main Project Preset | `release` |
| Build Generator | Ninja |
| C++ Standard | C++20 for the main project |

CMake and Ninja are installed inside the Distrobox container, not on the Bazzite host system.

---

## 3. Dependency Versions

The following Git revisions were present in the tested development environment.

| Component | Repository Location | Commit Hash |
|---|---|---|
| ModernGekko | `external/ModernGekko/` | `a2e4e2b026a68d4848f20ebf16f0e0ddeb573957` |
| Dolphin (ModernGekko fork) | `external/ModernGekko/vendor/dolphin/` | `cf8ceb81b47d6172164cd0572f57aa7624719f33` |
| DolRecomp | `external/ModernGekko/vendor/dolphin/DolRecomp/` | `71ce7f97419b1bb1ba9a9596c41507f6629e0fb0` |

### Dependency Integration

DolRecomp is included as a nested Git submodule inside ModernGekko's Dolphin dependency.

The SR-ZGS build script compiles DolRecomp directly from:

```text
external/ModernGekko/vendor/dolphin/DolRecomp/
```

This keeps the recompilation toolchain aligned with the Dolphin revision pinned by ModernGekko, helping maintain compatibility with the runtime module ABI.

All listed submodules were initialized at their recorded revisions during the dependency inspection.

---

## 4. Test Results

The following results were observed during developer testing on the Dell Inspiron 3558.

| Test | Result |
|---|---|
| Game Initialization | Successful |
| Game Execution | Successful |
| Full Game Completion | Successful |
| Observed Performance | 60 FPS |

### Performance Notes

The game successfully ran from start to finish on the hardware configuration documented above, with 60 FPS observed during developer testing.

This is an observed result from a specific test configuration, not a universal performance guarantee.

Actual performance may vary depending on hardware, runtime configuration, graphics settings and future changes.

SR-ZGS currently uses DolRecomp-generated code with ModernGekko, a Dolphin-derived runtime. The reported performance therefore represents the complete hybrid recompilation setup, not an independently implemented native runtime.

---

## 5. Testing Configuration

The following details have not yet been recorded and should be added when verified:

| Parameter | Status |
|---|---|
| Game Resolution | Not recorded |
| Graphics Settings | Not recorded |
| Test Date | Not recorded |
| FPS Measurement Method | Not recorded |
| Compiler Build Logs | Not archived |
| Additional Hardware Tests | Pending |

These fields are intentionally left undocumented rather than populated with estimated values.

---

## 6. Known Limitations

- The project currently relies on ModernGekko for graphics, audio, input and Wii system-level functionality.
- An independent runtime has not yet been implemented.
- Windows compatibility has not yet been verified.
- Android support remains a long-term development goal.
- Performance results have only been documented for the hardware configuration listed in this report.

---

## 7. Future Testing

Future compatibility reports should be documented separately, including their hardware and software configurations.

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
**Build Environment:** Distrobox  
**Current Runtime:** ModernGekko (Dolphin-derived)
