# Sonic Riders: Zero Gravity — Static Recompilation (SR-ZGS)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows-lightgrey)](#)
[![Engine](https://img.shields.io/badge/Recompiler-DolRecomp-orange)](#)

A modern, high-performance static recompilation project for **Sonic Riders: Zero Gravity** (Nintendo Wii).  
Designed with a clean, modular architecture isolating recompiled game logic, modding facilities, and hardware-agnostic platform hooks.

---

## 🏗️ Architecture

The repository enforces strict separation of concerns to guarantee performance and maintainability:

* `src/recompiled/`: Auto-generated and hand-tuned C/C++ code produced by `DolRecomp` from the original `main.dol`.
* `src/mod_loader/`: Core mod loading hooks, dynamic asset patching, and custom memory management.
* `src/platform/`: Platform abstraction layers (graphics rendering, audio backends, and input drivers).
* `src/expansions/`: Custom feature additions, extended engine limits, and experimental re-implementations.
* `external/`: Third-party dependencies and submodule integrations.
* `mods/`: Standard workspace directory for testing mod structures.

---

## ⚙️ Prerequisites & Setup

### Requirements
* **Compiler**: GCC 12+ or Clang 15+ (C++20 support required)
* **Build System**: CMake 3.22+
* **Recompilation Tool**: [DolRecomp](https://github.com/zelda264/DolRecomp)
* **Game Assets**: Legally acquired `main.dol` extracted from *Sonic Riders: Zero Gravity* (RS9E01 / RS9P01).

---
