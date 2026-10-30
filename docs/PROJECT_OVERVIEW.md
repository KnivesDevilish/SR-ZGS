# SR-ZGS — Project Overview

**Sonic Riders: Zero Gravity Source** is a static recompilation project for the original Nintendo Wii release of *Sonic Riders: Zero Gravity*, targeting Linux x86-64.

| Field | Value |
|---|---|
| Document version | 1.2 (Phase 0 closure synchronization) |
| Date | 2026-10-30 |
| Phase | Phase 0 — Project Definition and Environment Audit |
| Phase status | **IN PROGRESS**. Source and environment audit complete. The developer approved decisions D1, D2 and D4 on 2026-10-30. Formal closure of Phase 0 awaits the developer's explicit approval. D3 is due later, at the Phase 2 extraction gate. |
| Build status | **NOT BUILT**. The SR-ZGS repository exists but contains documentation only; nothing has been compiled, extracted or executed. |
| Source of truth | Phase 0 audit (2026-10-30) and developer-supplied terminal output |

---

## 1. Evidence labels

All SR-ZGS documents use these labels. No statement is upgraded to a stronger label without new evidence.

| Label | Meaning |
|---|---|
| **VERIFIED** | Directly inspected in upstream source code or repository history at a recorded commit. |
| **UPE** | User-provided evidence: terminal output the developer ran on the actual host or containers and supplied. Not independently inspected. |
| **SC** | Source-confirmed behavior: established by reading source code, not observed at runtime. |
| **TI** | Technical inference: reasoned from evidence but not directly confirmed. |
| **UNK** | Unknown. |
| **NOT TESTED** | Not executed by anyone. |

**VERIFIED is an evidence label only.**
- It never means that something was tested or that it works at runtime.
- Task progress uses a separate vocabulary defined in `DEVELOPMENT_ROADMAP.md`: NOT STARTED, IN PROGRESS, BLOCKED, IMPLEMENTED and TESTED.

---

## 2. Objective

Statically recompile the game's original PowerPC (Broadway) code into native Linux x86-64 code using DolRecomp's LLVM backend, then execute that code through the ModernGekko runtime.

The long-term product is a dedicated PC application named **Sonic Riders Zero Gravity Source** (Phase 8), with configurable graphics and controls and a native modding framework (Phase 7).

The objective is not simply to make the game run on Linux. It is to compile, integrate, execute, verify and optimize the game's original code as native host code, with every important result backed by evidence.

---

## 3. Architecture classification

SR-ZGS targets a **native recompilation runtime**: category 4 in the master development prompt.

| Category | Description | Role in SR-ZGS |
|---|---|---|
| 1. Static recompilation | Guest PowerPC code translated to host code before execution | Used for covered code (DolRecomp) |
| 2. Dynamic recompilation | Translation at runtime (JIT) | Present as the **fallback CPU** (Dolphin Jit64), SC |
| 3. Full emulation | Console CPU and hardware reproduced by an emulator | Not the target |
| 4. Native recompilation runtime | Statically recompiled code plus a runtime that provides hardware compatibility | **Target architecture** |

**SR-ZGS is not independent of Dolphin.**
- ModernGekko's runtime is built on RecompCore, a fork of the Dolphin emulator.
- Graphics, audio, input, Wii OS high-level emulation, disc access, timing and the fallback CPU are Dolphin-derived. Provenance is VERIFIED from `ModernGekko/PROVENANCE.md`; behavior is SC.
- Removing Dolphin-derived infrastructure would be a separate research milestone. It is not a current goal.

---

## 4. Upstream components

| Component | Role | Dolphin-derived? | Evidence |
|---|---|---|---|
| **DolRecomp** | PowerPC static recompiler (DOL, REL, RPX inputs; C and LLVM backends) | No | VERIFIED |
| **ModernGekko** | Runtime integration, game runner (`moderngekko-run`), launcher, porting tool (`moderngekko-port`), mod loader | Integration layer over Dolphin-derived code | VERIFIED |
| **RecompCore** (ModernGekko's `vendor/dolphin`) | Dolphin fork containing the StaticRecomp CPU core, the per-game module template and all hardware services | **Yes** | VERIFIED |
| **ModernGekko-Template** | Reference pipeline: a Makefile plus two submodules; contains no game code | No | VERIFIED |

Pinned revisions are in `DEPENDENCIES.md`. Pipeline details are in `TECHNICAL_ARCHITECTURE.md`.

---

## 5. Current state (2026-10-30)

**Established**
- The upstream repositories were inspected at recorded commits (VERIFIED).
- The recompilation pipeline, runtime, fallback behavior, REL handling and extraction paths are understood at source level (SC).
- The host and existing containers are documented (UPE); see `BUILD_ENVIRONMENT.md`.
- The SR-ZGS repository exists at `https://github.com/KnivesDevilish/SR-ZGS` (public). At commit `897e1b7` it contains `README.md`, `.gitignore`, `LICENSE` (GNU GPL version 3 text) and three image files under `docs/`. These five documents are placed in `docs/` as part of Phase 0 closure.

**Not yet done**
- The SR-ZGS repository has no source code, submodules, scripts or build configuration.
- No new dependencies have been installed specifically for SR-ZGS. Pre-existing host and container tools are documented in `BUILD_ENVIRONMENT.md`.
- No container has been created for SR-ZGS.
- Nothing has been compiled, extracted, recompiled or run.
- The game image has not been inspected. Its region, disc ID and executable/REL inventory are **UNK**.

**Critical blocker**
- DolRecomp's LLVM backend requires LLVM 19 or 20 (`19 <= version < 21`, VERIFIED).
- No LLVM 19/20 development files are present on the host or in the inspected container (UPE).
- Fedora 44 offers `llvm20-devel` 20.1.8, but it is not installed anywhere (see `DEPENDENCIES.md`).

---

## 6. Key findings that shape the project

1. **Only `main.dol` is recompiled.** The template pipeline sends only `main.dol` through recompilation (SC). RecompCore has REL runtime support, but the pipeline never produces the REL metadata or merged module needed to activate it (SC). REL code would therefore run on the Jit64 fallback (TI). Whether the game uses RELs is **UNK** until Phase 2.
2. **Selecting the StaticRecomp CPU core does not prove native execution.** All SC at ModernGekko `a2e4e2b`; see `TECHNICAL_ARCHITECTURE.md` §4–§6. Three separate mechanisms are involved, applied in this order by `Runtime::Create()`:
   1. **Module presence and validation (runner pre-check):**
      - A **missing** module is rejected unless `allow_interpreter` is explicitly enabled.
      - A module that fails to load or validate is a **fatal** error unless `allow_interpreter` is explicitly enabled.
   2. **Permission to continue without a module (`--allow-interpreter`):**
      - Only when this is explicitly given can startup continue without a usable module.
      - The runtime then clears the module configuration and the game runs without it, on Jit64.
   3. **CPU-core selection (`MODERNGEKKO_STATICRECOMP`):**
      - This happens only **after** the pre-check. The default is the StaticRecomp core.
      - `MODERNGEKKO_STATICRECOMP=0` selects JIT64 on x86-64.
      - It does **not** bypass the module-required or module-validation checks, and it does not permit a missing or rejected module.
      - A valid module may still pass validation, but the JIT64 core does not use it for CPU execution.
   - **Within the StaticRecomp core, when a module is active:** covered, hash-verified chunks execute through the native module, and uncovered chunks run on the Dolphin Jit64 fallback.
   - **Proof required:** native execution must be proven with runtime module-loading logs and native/fallback counters (NOT TESTED).
3. **The documented native-module mode has no consumer.** The `dolrecomp --runtime=moderngekko` "native module" mode documented in DolRecomp's README has no consuming code in the inspected ModernGekko or RecompCore revisions (SC, within the inspected scope). The supported path is DolRecomp's default output, built by RecompCore's module template.
4. **The LLVM version gap is real.** Fedora 44's default LLVM is 22.1.8, outside DolRecomp's accepted range. A compatibility package, `llvm20-devel` 20.1.8, exists in Fedora's package database.
5. **Available toolchains are newer than upstream CI.** GCC 16.2.1, CMake 4.3.0 and Python 3.14.x are all newer than what upstream CI uses. Compatibility is **NOT TESTED**.
6. **ModernGekko's launcher can extract discs from the command line** (`--extract <image>`, SC). A generic build rejects every disc, however (SC). It must be configured with the game's disc ID, which is not yet known.

---

## 7. Decisions

The developer approved D1, D2 and D4 on 2026-10-30. D3 remains open. The developer retains approval authority for every decision; this document records decisions and does not make them.

- **Required for G0 → Phase 1:** D1, D2 and D4, all approved. The gate also requires the developer's explicit approval to close Phase 0, which has not yet been given.
- **Decided later:** D3, at the Phase 2 extraction gate (G2-extract). It is **not** a prerequisite for, or a blocker to, starting Phase 1.
- Gate definitions are in `DEVELOPMENT_ROADMAP.md` §3.

| ID | Topic | Decision or recommendation | Decision gate | Status |
|---|---|---|---|---|
| D1 | Upstream pin set | Option B: ModernGekko `a2e4e2b` → RecompCore `cf8ceb8` → DolRecomp `71ce7f9`, with any external DolRecomp copy aligned to `71ce7f9`. ModernGekko-Template `c2553a9` is the architectural reference revision; its own submodule pins are not adopted. | G0 → 1 | **APPROVED** (2026-10-30) |
| D2 | Build environment | Dedicated Fedora 44 container, pinned by image digest, with least-privilege project mounts. Not the existing Toolbx container; the previous-attempt container is unused. Both existing containers are left untouched. | G0 → 1 | **APPROVED** (2026-10-30). Container **not created**; image digest **not selected**. |
| D3 | Disc extraction | Investigate and adapt the ModernGekko launcher's `--extract` mode first. `dolphin-tool` is the alternative and needs an integrity-validation wrapper. `wit` only with explicit approval and checksum pinning. | G2-extract (Phase 2) | **RECOMMENDED, NOT APPROVED**; not required for Phase 1 |
| D4 | Repository path, remote visibility, license for SR-ZGS-owned code | Repository `KnivesDevilish/SR-ZGS`, public, GPL-3.0 | G0 → 1 | **APPROVED** (2026-10-30) |

---

## 8. Intellectual property and licensing

- **Game data.** The developer supplies a legally obtained dump of their own disc. No ISO, extracted game files, keys or copyrighted assets may enter any repository or release.
- **Version control.**
  - The template's `.gitignore` excludes `iso/`, `extracted/`, `generated/`, `build/`, `extern/` and `database/` (VERIFIED).
  - The SR-ZGS `.gitignore` (since commit `680ec01`) excludes `/iso/`, `/extracted/`, `/generated/` and `/build/`, common disc-image formats, and `*.dol` and `*.rel` files.
  - It does not yet exclude `extern/` or `database/`. In the template these hold upstream tool downloads (`wit`, and GameTDB `titles.txt` fetched by `dolrecomp --setup`), not game data (SC). Adding them, and `runtime/`, is a Phase 1 task if the adapted pipeline creates those directories (`DEVELOPMENT_ROADMAP.md` §4).
- **Generated modules.** Game modules embed recompiled game code.
  - **What upstream states:** the module-template documentation (`RecompCore/module-template/README.md`) treats generated modules as derived works and instructs users not to redistribute them. That this statement exists is VERIFIED.
  - **SR-ZGS policy:** SR-ZGS adopts a conservative distribution policy in which users build modules from their own legally obtained game dumps, pending final legal review.
  - **Legal status:** this policy is a project decision, not an independent legal determination. The final legal interpretation remains subject to review in Phase 9.
- **Upstream licenses.**
  - ModernGekko is GPL-3.0-or-later because of its Dolphin-derived runtime (VERIFIED: `README` and `PROVENANCE.md`).
  - DolRecomp is described as GPLv3 in ModernGekko's `PROVENANCE.md` (VERIFIED as stated there).
  - Obligations for distributing combined binaries must be reviewed in Phase 9.
- **SR-ZGS-owned code.** GPL-3.0 (D4, approved 2026-10-30). The repository's `LICENSE` contains the GNU GPL version 3 text. Whether SR-ZGS files are offered under "version 3 only" or "version 3 or any later version" is not yet stated; no per-file license notices exist yet.

---

## 9. Product identity

- The user-facing application will be named **Sonic Riders Zero Gravity Source**.
- Internal names (DolRecomp, ModernGekko, disc IDs) must not be the application's primary window title.
- ModernGekko provides build-time branding options. Their existence is VERIFIED in `ModernGekko/CMakeLists.txt`; their behavior is **NOT TESTED**:
  - `MODERNGEKKO_FRONTEND_NAME`
  - `MODERNGEKKO_DEFAULT_WINDOW_TITLE`
  - `MODERNGEKKO_LAUNCHER_OUTPUT_NAME`
  - `MODERNGEKKO_RUNNER_OUTPUT_NAME`
  - `MODERNGEKKO_USER_DIRECTORY_NAME`
  - `MODERNGEKKO_REQUIRED_DISC_ID`
  - `MODERNGEKKO_REQUIRED_DOL_SHA256`
  - `MODERNGEKKO_REQUIRED_ASSETS_SHA256`
- **Warning.** ModernGekko's launcher contains a compile-time branch for a different product, the Sonic Riders "Tournament Edition 2.4.6.1" disc preparer (SC). It is unrelated to SR-ZGS and must remain disabled. See `TECHNICAL_ARCHITECTURE.md` §10.

---

## 10. Documentation set

| Document | Content | Status |
|---|---|---|
| `PROJECT_OVERVIEW.md` | This document | Updated, Phase 0 closure |
| `TECHNICAL_ARCHITECTURE.md` | Pipeline, runtime, fallback, evidence signals, DOL/REL, extraction | Updated, Phase 0 closure |
| `DEPENDENCIES.md` | Upstream pins, toolchain, libraries, reproducibility policy | Updated, Phase 0 closure |
| `DEVELOPMENT_ROADMAP.md` | Phases 0–9, approval gates, risk register | Updated, Phase 0 closure |
| `BUILD_ENVIRONMENT.md` | Reported baseline plus developer-supplied (UPE) host and container evidence | Updated, Phase 0 closure |

**Later documents.** These are created only when their phase produces verifiable information: `GAME_IDENTIFICATION.md`, `DISC_MANIFEST.md`, `MODULE_INVENTORY.md`, `MODULE_DEPENDENCIES.md`, `RECOMPILATION_REPORT.md`, `CODE_COVERAGE.md`, `RUNTIME_INTEGRATION.md`, `COMPATIBILITY_REPORT.md`, `PERFORMANCE_REPORT.md`, `MODDING_SYSTEM.md`, `RELEASE_NOTES.md`.

**README.** The repository's `README.md` is the public entry point. It summarizes these documents; the technical detail stays here.

**Location.** All five documents live in the SR-ZGS repository under `docs/`, as the master development prompt (§7) requires. They were first drafted outside the repository and moved into `docs/` when Phase 0 was prepared for closure.
