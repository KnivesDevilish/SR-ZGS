# SR-ZGS — Sonic Riders: Zero Gravity Source

SR-ZGS is a static recompilation project for the Nintendo Wii game *Sonic Riders: Zero Gravity*. Its aim is to translate the game's original PowerPC code into native Linux x86-64 code with the LLVM backend of [DolRecomp](https://github.com/ExpansionPak/DolRecomp), and to run that code on the [ModernGekko](https://github.com/ExpansionPak/ModernGekko) runtime. ModernGekko's hardware-compatibility layer is derived from the Dolphin emulator.

SR-ZGS is not a Dolphin launcher, a set of Gecko codes, an emulator configuration or a rewrite of the game engine.

> **Pre-implementation.** This repository holds this README, a `.gitignore`, the license and three image files. No code has been written, built, recompiled or run, and nothing here can play the game.

---

## Current status

| Item | Status |
|---|---|
| Current phase | **Phase 0**, project definition and environment audit. The audit is complete, and decisions D1, D2 and D4 are approved. |
| Phase 1 (clean project initialization) | **NOT STARTED**. It starts only with the developer's explicit approval. |
| Repository contents | `README.md`, `.gitignore`, `LICENSE` and three PNG images under `docs/`. There is no source code, build system, script, submodule or CI workflow. |
| Builds | None. DolRecomp, ModernGekko and RecompCore have not been built for SR-ZGS. |
| Game | Not identified, extracted, recompiled or run. |
| Tests | None executed. |

**Decisions**

| ID | Decision | Status |
|---|---|---|
| D1 | Upstream pin set (see [Dependency baseline and pins](#dependency-baseline-and-pins)) | Approved |
| D2 | Build environment: a dedicated Fedora 44 container, pinned by image digest, with least-privilege project mounts | Approved. The container has not been created. |
| D3 | Disc extraction method | Open. It is decided at the Phase 2 extraction gate. |
| D4 | Repository `KnivesDevilish/SR-ZGS`, public, GPL-3.0 | Approved |

---

## Objective

- Statically recompile the game's PowerPC (Broadway) code into native x86-64 code, using DolRecomp's LLVM backend.
- Execute that code through the ModernGekko runtime.
- Account for all executable code the game uses: `main.dol`, plus any REL modules (whether the game uses RELs is unknown until Phase 2). Coverage is measured, not assumed.
- Work in this order: correct execution first, complete functionality second, performance third.

Long-term goals, none of them implemented yet:
- Configurable graphics and controls.
- A native modification framework (Phase 7).
- A dedicated PC application named **Sonic Riders Zero Gravity Source** (Phase 8).

---

## Technical architecture

Everything in this section comes from reading upstream source code at the pinned revisions. None of it has been observed at runtime yet.

### Classification

SR-ZGS targets a **native recompilation runtime**: statically recompiled game code running on a runtime that supplies hardware compatibility. It is not full emulation, and it is **not independent of Dolphin**. Removing the Dolphin-derived infrastructure is not a current goal; it would be a separate research milestone.

### Components

| Component | Role | Dolphin-derived? |
|---|---|---|
| **DolRecomp** | Static recompiler for PowerPC DOL and REL executables, with C and LLVM backends. SR-ZGS uses the LLVM backend. | No |
| **ModernGekko** | Runtime integration layer: game runner (`moderngekko-run`), porting tool (`moderngekko-port`) and launcher | Its own code is not, but it is built on RecompCore. It also vendors Dolphin-derived code in `vendor/dolphin_legacy`. |
| **RecompCore** | ModernGekko's vendored Dolphin fork (`vendor/dolphin`). It contains the StaticRecomp CPU core, the Jit64 fallback, the per-game module template, and the graphics, audio, input, Wii OS high-level emulation, disc I/O and timing services. | **Yes** |
| **ModernGekko-Template** | Reference pipeline (a Makefile and two submodules), used as the architectural starting point. It contains no game code. | No |

### Upstream pipeline

```text
Disc image (supplied by the developer; never committed)
   │  extraction: method decided in Phase 2 (D3)
   ▼
Extracted game root: sys/main.dol, sys/boot.bin, files/
   │  moderngekko-port (ModernGekko) runs the nested DolRecomp, LLVM backend
   ▼
Generated native objects (main.dol code only)
   │  RecompCore module template (CMake + Ninja)
   ▼
Native module: g<DISCID>_recomp.so
   │  moderngekko-run, with RecompCore's StaticRecomp CPU core
   ▼
Execution: covered code runs natively; uncovered code runs on Dolphin Jit64
```

### Who executes what

| Question | Answer |
|---|---|
| What runs game CPU code? | With the default StaticRecomp core and an active module, covered, hash-verified code chunks run through the native module. Uncovered chunks run on the **Dolphin Jit64** fallback. |
| What provides hardware compatibility? | RecompCore (Dolphin-derived): video, audio/DSP, input, Wii OS high-level emulation, disc I/O and timing. |
| What is statically recompiled? | In the upstream template pipeline, `main.dol` only. |
| What comes from Dolphin? | All of RecompCore (`vendor/dolphin`) and ModernGekko's `vendor/dolphin_legacy`. |

### Runtime startup order

`Runtime::Create()` in ModernGekko applies three separate mechanisms, in this order:

1. **Module pre-check.**
   - A missing native module is rejected.
   - A module that fails to load or validate is a fatal error.
   - Both apply unless `--allow-interpreter` is given.
2. **`--allow-interpreter`.** Only with this option does startup continue without a usable module. The runtime then clears the module and the game runs without it, on Jit64.
3. **CPU-core selection**, after the pre-check. The default is the StaticRecomp core.
   - `MODERNGEKKO_STATICRECOMP=0` selects the JIT64 core.
   - It does **not** bypass module validation. A missing or rejected module still requires `--allow-interpreter`.
   - With the JIT64 core, a valid module may pass validation, but it is not used for CPU execution.

Selecting the StaticRecomp core does not prove that native code is running. That proof requires runtime module-loading logs and native/fallback execution counters (Phase 4).

### Known architectural gaps

- **REL code is not covered.**
  - DolRecomp can recompile REL modules, and the RecompCore runtime has REL remapping support.
  - The upstream pipeline sends only `main.dol` to the recompiler.
  - RecompCore's module template never fills in the REL metadata the runtime needs.
  - REL code would therefore run on Jit64. Closing this gap, if the game uses RELs, is Phase 3 work.
- **The documented "native module" mode has no consumer.** DolRecomp's README documents a `--runtime=moderngekko` mode. No code in the pinned ModernGekko or RecompCore revisions consumes its output. SR-ZGS uses the supported path instead: DolRecomp's default output, built into a module by RecompCore's module template.

---

## Dependency baseline and pins

These are the approved revisions (D1). SR-ZGS does not substitute newer upstream HEAD revisions. Newer revisions exist; for example, DolRecomp `main` was at `02e27ac` when it was audited. None of these pins has been added to this repository as a submodule yet; that happens in Phase 1.

| Component | Repository | Commit |
|---|---|---|
| ModernGekko | <https://github.com/ExpansionPak/ModernGekko> | `a2e4e2b026a68d4848f20ebf16f0e0ddeb573957` |
| RecompCore | <https://github.com/ExpansionPak/RecompCore> (branch `moderngekko-vendor`) | `cf8ceb81b47d6172164cd0572f57aa7624719f33` |
| DolRecomp | <https://github.com/ExpansionPak/DolRecomp> | `71ce7f97419b1bb1ba9a9596c41507f6629e0fb0` |
| ModernGekko-Template (listed as "Module Template" in the approved pin set) | <https://github.com/ExpansionPak/ModernGekko-Template> | `c2553a99584b2045dbe46a70e1570994dae8beef` |

**How the pins relate**
- ModernGekko `a2e4e2b` pins its `vendor/dolphin` submodule to RecompCore `cf8ceb8`.
- RecompCore `cf8ceb8` pins its DolRecomp submodule to `71ce7f9`. This nested copy is the DolRecomp that actually recompiles.
- ModernGekko-Template `c2553a9` is used as a reference. Its own submodules pin ModernGekko `edd460a` and DolRecomp `1bec355`. SR-ZGS does **not** adopt those two pins.
- Any top-level DolRecomp checkout added to SR-ZGS must point to the same commit as the nested one, `71ce7f9`.

**Toolchain requirements stated by the pinned upstream build files**

| Requirement | Version |
|---|---|
| LLVM development files (with the X86 target) | **19 ≤ version < 21** |
| CMake | 3.20 or later. RecompCore also declares a maximum *policy* version of 4.2.1; this is not an upper limit on the CMake version. |
| Ninja, GNU Make, Git (with submodules), pkg-config | Required; no versions stated |
| C and C++ compilers | C11. C++23 for ModernGekko and RecompCore; C++17 for DolRecomp's LLVM backend. Minimum compiler versions are not stated. |
| Python 3 | Required by the per-game module template |

**LLVM status.** Fedora 44's default `llvm-devel` (22.1.8) is outside DolRecomp's accepted range. Fedora 44 also offers `llvm20-devel` 20.1.8, which is not installed anywhere yet. Whether it builds DolRecomp correctly has not been tested.

---

## Target platform and development environment

**Target.** Linux x86-64 only. No other operating system is supported. Any later port would be a secondary portability target.

**Build environment (D2, approved, not yet created)**
- A dedicated Fedora 44 container.
- The base image is pinned by digest. The digest and a full package list are recorded when the container is created in Phase 1.
- Least-privilege mounts:
  - Only the SR-ZGS project directory, plus an optional cache directory, is mounted.
  - No privileged mode.
  - No host PID or IPC namespaces.
  - No host root filesystem and no full home directory.
- The container tool and the network policy are chosen in Phase 1.
- How graphics and audio are tested at runtime is decided in Phase 4.
- The developer's existing containers, `my-distrobox` and `recomp`, are not used and are left untouched.

**Developer host** (as reported by the developer; this describes the machine, not a requirement)

| Item | Value |
|---|---|
| OS | Bazzite 44 (Kinoite variant, image `44.20260915.0`), Fedora 44 base |
| Kernel | `7.2.4-ogc3.1.fc44.x86_64` |
| CPU | Intel Core i5-5200U, 2 cores / 4 threads, x86-64-v3 |
| RAM | 15 GiB |
| Storage | Mechanical HDD |
| GPU | Intel HD Graphics 5500 (`i915`, Mesa 26.2.2, OpenGL 4.6). Vulkan enumerates the GPU and llvmpipe. |

**Toolchain compatibility (not tested).** The toolchain versions observed in an existing Fedora 44 container (GCC 16.2.1, CMake 4.3.0, Python 3.14) are newer than those used by upstream CI. Upstream ModernGekko CI builds only the C backend, not the LLVM path.

---

## Repository documentation index

Files that exist in this repository:

| Path | Contents |
|---|---|
| `README.md` | This file |
| `LICENSE` | GNU General Public License, version 3 |
| `.gitignore` | Rules that keep build output and game data out of version control |
| `docs/` | Three PNG images: `SR-ZGS Banner.png`, `SR-ZGS Logo.png` and `SR-ZGSxNTH.png`. No written documentation yet. |
| `.github/` | Placeholder (`.gitkeep`) only; no workflows |

**Phase 0 documents.** Five documents are maintained in the project's working documentation and have **not** been committed to this repository:
- `PROJECT_OVERVIEW.md`
- `TECHNICAL_ARCHITECTURE.md`
- `DEPENDENCIES.md`
- `DEVELOPMENT_ROADMAP.md`
- `BUILD_ENVIRONMENT.md`

Moving them into `docs/` is a Phase 1 task. Until then, this README summarizes them.

**Later documents.** Each phase's report is created only when that phase produces verifiable results.

---

## Development phases and progress

Each phase starts only after the previous one is validated and the developer explicitly approves the transition.

| Phase | Name | Status |
|---|---|---|
| 0 | Project definition and environment audit | **IN PROGRESS**: audit complete; D1, D2 and D4 approved; Phase 0 documents not yet committed here |
| 1 | Clean project initialization | NOT STARTED |
| 2 | Game extraction and analysis | NOT STARTED |
| 3 | Static recompilation pipeline | NOT STARTED |
| 4 | ModernGekko runtime integration | NOT STARTED |
| 5 | Game compatibility and verification | NOT STARTED |
| 6 | Performance optimization | NOT STARTED |
| 7 | Gameplay modifications | NOT STARTED |
| 8 | Native PC application | NOT STARTED |
| 9 | Release preparation | NOT STARTED |

**Status vocabulary**
- NOT STARTED
- IN PROGRESS
- BLOCKED
- IMPLEMENTED: the code exists.
- TESTED: a test was executed and its evidence (logs, output, measurements) recorded.

A successful build command alone never makes a phase TESTED.

**What each phase covers** (planned; refined at each approval gate)

| Phase | Planned work |
|---|---|
| 1 | Create the build container and install the toolchain, including LLVM 20. Add submodules at the approved pins. Write an adapted Makefile with no automatic downloads. Run toolchain smoke builds, without game data. |
| 2 | Identify the disc (ID and region). Choose the extraction method (D3) and extract. Record hashes and a disc manifest. Inventory `main.dol` and any REL modules. |
| 3 | Run DolRecomp's LLVM pipeline. Produce a coverage report covering both DOL and REL code, and list unsupported or fallback code. |
| 4 | Integrate the module with ModernGekko. Prove native execution from logs and counters. Check graphics, audio, input, file access, saves and timing. |
| 5 | Check compatibility across the whole game, not only boot. |
| 6 | Measure performance against Dolphin under equivalent conditions. |
| 7 | Native, isolated and reversible gameplay modifications. |
| 8 | The *Sonic Riders Zero Gravity Source* PC application. |
| 9 | Reproducible release, license review and documentation. |

**Carried-forward blocker.** No LLVM 19 or 20 development files are installed on the host or in any existing container. Phase 1 resolves this in the new container, subject to approval.

---

## Game ownership and extraction policy

- **Bring your own copy.** You must supply a legally obtained dump of your own disc. This project does not provide, link to or help obtain game images or game files.
- **Never commit game data.** Do not commit or upload any of these to this public repository, its issues or pull requests:
  - disc images;
  - extracted game files;
  - `main.dol` or REL executables;
  - generated recompiled code or native modules;
  - keys;
  - any other copyrighted game asset.

  The `.gitignore` excludes the common locations and formats. It is a safety net, not a guarantee.
- **Game identity is unverified.** The disc ID, region and title ID are not known. They will be read from the actual disc in Phase 2. Nothing in this repository is configured for a specific disc ID.
- **No extraction method is approved.**
  - The method (D3) is chosen at the Phase 2 extraction gate, and this README provides no extraction or build commands.
  - The leading candidate, ModernGekko's launcher extraction mode, accepts a disc only when built for that disc's ID. The disc must therefore be identified first, with a read-only method that has not yet been chosen.
  - Downloading third-party tools needs separate approval and a pinned checksum. This includes Wiimms ISO Tools, which the upstream template downloads automatically.
- **Structural checks do not verify a dump.**
  - The runtime's game inspection checks for required files, reads the disc ID from the disc header and validates the DOL section table.
  - Passing those checks does not show that a dump is complete or unmodified.
  - Reusing an existing extraction does not prove it is byte-for-byte identical to the disc.
  - Dump integrity will be established with recorded hashes in Phase 2.
- **Generated modules.** Generated modules embed recompiled game code. Upstream module-template documentation treats generated modules as derived works and instructs users not to redistribute them. SR-ZGS adopts a conservative distribution policy in which users build modules from their own legally obtained game dumps, pending final legal review (Phase 9).

---

## Licensing and third-party acknowledgments

**SR-ZGS.** Files owned by SR-ZGS are licensed under the GNU General Public License, version 3. The full text is in [`LICENSE`](LICENSE).

**Upstream projects.** DolRecomp, ModernGekko, RecompCore and ModernGekko-Template are published at <https://github.com/ExpansionPak>. Their licenses, as stated upstream:

| Component | License |
|---|---|
| ModernGekko | GPL-3.0-or-later, because of its Dolphin-derived runtime (per its `LICENSE` and `PROVENANCE.md`) |
| RecompCore (Dolphin fork) | Mostly GPL-2.0-or-later, in a combined tree described upstream as GPLv3-compatible. Per-file SPDX identifiers are authoritative. |
| DolRecomp | GPLv3, as described in ModernGekko's `PROVENANCE.md`. DolRecomp's own license file is reviewed in Phase 9. |
| Bundled third-party libraries | Each under its own license; reviewed in Phase 9 |

**Dolphin.** RecompCore and ModernGekko's runtime are derived from the [Dolphin](https://dolphin-emu.org/) GameCube and Wii emulator, developed by the Dolphin Emulator Project.

**Distribution.** The obligations for distributing combined binaries have not yet been reviewed; that review is part of Phase 9.

**Trademarks.** *Sonic Riders: Zero Gravity* was published by SEGA. Sonic the Hedgehog and related names are trademarks of SEGA. Wii is a trademark of Nintendo. SR-ZGS is an unofficial project and is not affiliated with or endorsed by SEGA or Nintendo.

---

## Limitations and work not yet implemented

**Nothing is implemented**
- There is no source code, build system, script, submodule or CI workflow.
- The build container does not exist, and LLVM 20 is not installed.
- The game has not been identified, extracted or recompiled. No native module exists, and nothing has run.
- There is no launcher, PC application, settings interface, controller configuration or modification support.

**Known technical limitations** (from source inspection; not tested)
- REL code is not covered by the upstream pipeline. It would run on the Jit64 fallback. See [Known architectural gaps](#known-architectural-gaps).
- Native execution is unproven until runtime logs and native/fallback counters show it.
- The pinned revisions have not been built with any toolchain, and toolchain compatibility is untested.
- GPU selection (Intel HD Graphics 5500 versus llvmpipe) and graphics, audio and input behavior are untested.
- Upstream provides no in-app controller configuration. Input bindings come from configuration files in the user directory, which nothing creates.
- The runtime hashes the entire extracted game `files/` tree on every run. Its cost on the developer's mechanical HDD has not been measured.

**Withdrawn claims.** Earlier versions of this README described features that do not exist, including:
- support for other platforms;
- frame-rate and resolution targets;
- a custom renderer;
- new game content;
- localization.

Those descriptions are withdrawn. A feature will be documented here only once it exists and has been tested.
