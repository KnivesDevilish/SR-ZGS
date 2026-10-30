<h1 align="center">Sonic Riders: Zero Gravity Source</h1>

<p align="center">
  <strong>SR-ZGS</strong> · A static recompilation project for <em>Sonic Riders: Zero Gravity</em> (Nintendo Wii), targeting native Linux x86-64
</p>

<p align="center">
  <sub>Early development · Phase 0 audit complete · No playable build yet</sub>
</p>

---

## About

SR-ZGS aims to turn the original PowerPC code of *Sonic Riders: Zero Gravity* into native x86-64 code for Linux. It uses DolRecomp's LLVM backend to translate the code, and runs the result on the ModernGekko runtime.

It is not a Dolphin launcher, an emulator configuration, a Gecko code pack or an engine rewrite. The goal is to compile, run, verify and eventually optimize the game's own code as native host code.

The long-term product is a dedicated PC application, **Sonic Riders Zero Gravity Source**.

## What makes it static recompilation

An emulator translates a game's code while it runs. SR-ZGS translates it **before** it runs:

- **Ahead of time.** DolRecomp turns the Wii's Broadway PowerPC code into a native module for the host machine.
- **Native where covered.** Code the module covers runs natively through the StaticRecomp CPU core. Code it does not cover falls back to a JIT64 dynamic recompiler.
- **Runtime services.** Graphics, audio, input, disc access and timing come from the runtime.

SR-ZGS is **not independent of Dolphin**. ModernGekko is built on RecompCore, a fork of Dolphin, and that is where the hardware layer and the JIT64 fallback come from.

## Project status

| Area | Status |
|---|---|
| Phase 0: audit | Audit complete. Document synchronization and formal phase closure pending. |
| Phase 1: initialization | Not started |
| SR-ZGS source code | None written, built or tested yet |
| Build environment | Dedicated Fedora 44 container approved, not yet created. Image digest not yet selected. |
| Decisions | D1 (upstream pins), D2 (build environment) and D4 (repository and license) approved. D3 (extraction method) pending until Phase 2. |
| Game | Disc ID, region and REL inventory unknown until Phase 2 |

## Technology stack

| Layer | Component | Role |
|---|---|---|
| Recompiler | [DolRecomp](https://github.com/ExpansionPak/DolRecomp) (LLVM backend) | Translates PowerPC Broadway code into a native x86-64 module |
| Runtime | [ModernGekko](https://github.com/ExpansionPak/ModernGekko) | Loads the native module and runs the game |
| Hardware layer | [RecompCore](https://github.com/ExpansionPak/RecompCore) (Dolphin-derived) | StaticRecomp core, JIT64 fallback, graphics, audio, input, disc I/O |
| Pipeline reference | [ModernGekko-Template](https://github.com/ExpansionPak/ModernGekko-Template) | Architectural starting point for the build pipeline |
| Platform | Linux x86-64 | Builds will use a dedicated Fedora 44 container |

Each upstream component has an approved, fixed revision. Newer upstream revisions are not substituted automatically.

## Architecture

```text
   Your own legally obtained game disc
                  │
                  ▼
              main.dol
                  │  DolRecomp · LLVM backend
                  ▼
        Native x86-64 game module
                  │
                  ▼
   ModernGekko runtime + RecompCore services
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
  Covered code        Uncovered code
  runs natively       JIT64 fallback
```

- The upstream pipeline, as inspected, recompiles **`main.dol` only**.
- Integrating REL modules is **not yet established**. Whether the game uses RELs will be known after Phase 2.
- Native execution still has to be proven at runtime, with module-loading logs and native/fallback execution counters.

## Roadmap

| Phase | Focus |
|---|---|
| **0 · Audit** | Upstream source and environment audit (**audit complete**) |
| **1 · Initialization** | Build container, pinned dependencies, toolchain smoke builds |
| **2 · Game analysis** | Disc identification, extraction, executable and REL inventory |
| **3 · Recompilation** | LLVM pipeline, coverage report |
| **4 · Runtime integration** | Load the module and prove native execution |
| **5 · Compatibility** | Verify the whole game, not just the boot |
| **6 · Performance** | Measured optimization, compared against Dolphin |
| **7 · Modifications** | Native, isolated and reversible gameplay patches |
| **8 · PC application** | *Sonic Riders Zero Gravity Source* |
| **9 · Release** | Reproducible builds, packaging, license review |

### Immediate objectives

1. Synchronize the Phase 0 documents with the approved decisions, then formally close Phase 0.
2. Create the Fedora 44 build container, select and pin its image digest, and install the toolchain.
3. Add the upstream dependencies at their approved revisions.
4. Commit the technical documentation to `docs/`.
5. Smoke-build DolRecomp and ModernGekko without any game data.

## Game data and licensing

SR-ZGS contains **no game data** and never will. Use a legally obtained dump of your own disc.

Do not commit or upload any of the following:
- disc images;
- extracted files;
- game executables;
- generated modules;
- keys.

Generated modules contain recompiled game code. They are built locally from your own copy and are not distributed.

SR-ZGS is licensed under the [GNU General Public License v3.0](LICENSE). Upstream components keep their own licenses; ModernGekko, for example, is GPL-3.0-or-later.

*Sonic Riders: Zero Gravity* is published by SEGA. Sonic the Hedgehog and related names are trademarks of SEGA, and Wii is a trademark of Nintendo. SR-ZGS is an unofficial project and is not affiliated with or endorsed by SEGA or Nintendo.

## Acknowledgments

- **ExpansionPak**, for DolRecomp, ModernGekko, RecompCore and ModernGekko-Template.
- **The [Dolphin](https://dolphin-emu.org/) Emulator Project**, whose work underpins RecompCore.
- **Sonic Team and SEGA**, creators of the original game.
