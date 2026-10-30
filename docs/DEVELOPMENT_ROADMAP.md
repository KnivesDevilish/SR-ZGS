# SR-ZGS — Development Roadmap

| Field | Value |
|---|---|
| Document version | 1.2 (Phase 0 closure synchronization) |
| Date | 2026-10-30 |
| Current phase | Phase 0 — **IN PROGRESS**: audit complete; D1, D2 and D4 approved (2026-10-30); formal closure awaits the developer's explicit approval. Phase 1 has **not** started. |
| Rule | Each phase starts only after the previous phase is validated and the developer explicitly approves it. |

Evidence labels (VERIFIED, UPE, SC, TI, UNK, NOT TESTED) are defined in `PROJECT_OVERVIEW.md` §1.

**Task status vocabulary.** This vocabulary is separate from the evidence labels.

| Status | Meaning |
|---|---|
| NOT STARTED | No work done |
| IN PROGRESS | Work under way |
| BLOCKED | Waiting on another requirement |
| IMPLEMENTED | The code exists |
| TESTED | A successful test was executed and its evidence (logs, output, measurements) recorded |

- **Source inspection alone never makes a task TESTED.** At most, a source-level finding can be labeled SC or VERIFIED as evidence.
- **VERIFIED is not used as a task status in SR-ZGS documents.** It is reserved for the evidence label.
- **Mapping to the master prompt.** The master development prompt's task status "VERIFIED" corresponds to **TESTED** here.

---

## 1. Phase overview

| Phase | Name | Status |
|---|---|---|
| 0 | Project definition and environment audit | **IN PROGRESS**: audit complete; D1, D2 and D4 approved; formal closure pending (D3 is decided later, at G2-extract) |
| 1 | Clean project initialization | NOT STARTED |
| 2 | Game extraction and analysis | NOT STARTED |
| 3 | Static recompilation pipeline | NOT STARTED |
| 4 | ModernGekko runtime integration | NOT STARTED |
| 5 | Game compatibility and verification | NOT STARTED |
| 6 | Performance optimization | NOT STARTED |
| 7 | Gameplay modifications | NOT STARTED |
| 8 | Native PC application | NOT STARTED |
| 9 | Release preparation | NOT STARTED |

---

## 2. Phase 0: status

**Complete**
- Upstream source audit of DolRecomp, ModernGekko, RecompCore and ModernGekko-Template at recorded commits (VERIFIED/SC).
- Host environment evidence (UPE).
- Existing-container evidence, plus its security and reproducibility assessment (UPE).
- Source-level analysis of the recompilation architecture, fallback behavior and REL handling (SC).
- Source-level analysis of the extraction tools (SC).
- The five Phase 0 documents (this set), placed in the repository's `docs/`.
- Developer decisions **D1, D2 and D4**, approved on 2026-10-30 (`PROJECT_OVERVIEW.md` §7).
- The SR-ZGS repository (`KnivesDevilish/SR-ZGS`, public, GPL-3.0) exists with `README.md`, `.gitignore` and `LICENSE`. It holds no source code, submodules, scripts or game data.

**Pending**
- Developer review of the synchronized Phase 0 documents.
- The developer's explicit approval to close Phase 0 (gate G0 → 1).

**Not pending for Phase 1**
- **D3 (disc extraction)** remains a recommendation until the extraction-method decision at **G2-extract**, in Phase 2.
- It is **not** a blocker for starting Phase 1.

The developer retains approval authority for all decisions. This document records decisions; it does not make them.

**Blocker carried forward**
- No LLVM 19/20 development files anywhere (UPE). Resolving it needs an approved installation in a new environment (Phase 1).

**Readiness**
- The Phase 0 **source and environment audit** is complete. Formal closure of Phase 0 is still pending.
- The project is **not** implementation-ready: nothing has been built, and the toolchain is untested.

---

## 3. Approval gates

All gates require explicit developer approval; the developer retains authority over every decision.

| Gate | What requires explicit developer approval |
|---|---|
| G0 → 1 | Close Phase 0; decide **D1** (pins), **D2** (environment) and **D4** (repository path, visibility, license). D1, D2 and D4 were approved on 2026-10-30; the closure approval is still pending. **D3 is not required at this gate.** |
| G1-env | Create the build container; install packages, including `llvm20-devel` |
| G1-build | Toolchain smoke builds of DolRecomp and ModernGekko (no game data) |
| G1 → 2 | Repository and toolchain validated |
| G2-extract | **D3**: extraction method, decided here in Phase 2. Until then D3 is a recommendation only. Any `wit` download needs separate approval and a checksum pin. |
| G2 → 3 | Disc identified; executable and REL inventory complete |
| G3 → 4 | Native module produced; coverage report reviewed |
| Later gates | Every phase transition; any host change; any download of third-party binaries |

---

## 4. Phase plans

These plans are proposals and will be refined at each gate.

### Phase 1 — Clean project initialization

- **Depends on:** D1, D2, D4 (all approved), and the closure of Phase 0.
- **Tasks:**
  1. Select the base-image digest, then create the dedicated Fedora 44 build container: digest-pinned base image, least-privilege mounts, package manifest recorded (`BUILD_ENVIRONMENT.md` §7).
  2. Install the toolchain, including `llvm20-devel`. Confirm that `LLVMConfigVersion.cmake` reports 20.1.x.
  3. Repository: already created by the developer before Phase 1 (`KnivesDevilish/SR-ZGS`). Phase 1 adds only new, verified content; nothing is inherited from previous attempts.
  4. Add submodules at the approved commits; record `git submodule status --recursive`.
  5. Extend the existing `.gitignore` as needed. It already covers `/iso/`, `/extracted/`, `/generated/`, `/build/`, common disc-image formats, `*.dol` and `*.rel`. Add `extern/`, `database/` and `runtime/` if the adapted pipeline creates those directories.
  6. Write an adapted Makefile:
     - No automatic downloads.
     - Conservative default job count (start at 2).
     - Build trees outside the submodule worktrees.
     - A `check` target that includes a pin-consistency check (external DolRecomp vs nested DolRecomp).
  7. Keep the documents in `docs/` up to date. (They were moved into `docs/` during Phase 0 closure.)
  8. Toolchain smoke build (separate approval): DolRecomp with the LLVM backend, plus its test suite; then ModernGekko's `moderngekko-port`. Measure peak memory and build time on the HDD.
- **Validation:**
  - A fresh recursive clone into a second directory succeeds.
  - `make check BACKEND=llvm` passes.
  - Superproject and submodules are clean.
  - No game data is present.
- **Key risks:** compatibility of GCC 16.2.1, CMake 4.3.0 and Python 3.14; Fedora LLVM linking mode; shallow-submodule fetch failures.

### Phase 2 — Game extraction and analysis

- **Depends on:** D3, decided at G2-extract.
- **Tasks:**
  1. Read-only disc identification to determine region, disc ID and revision. The method is still to be decided (`TECHNICAL_ARCHITECTURE.md` §10.2, step 1).
  2. Validate the image: compare its hash against an independent reference.
  3. Extract with the approved method:
     - Preferred candidate: launcher `--extract`, built with `MODERNGEKKO_REQUIRED_DISC_ID=<identified ID>`, with the preparer disabled and an isolated user directory.
     - Alternative: `dolphin-tool` with a validation wrapper.
  4. Run the completeness validation (`TECHNICAL_ARCHITECTURE.md` §10.5).
  5. Locate `main.dol`. Inventory all REL and other executable modules; record their load mechanism and dependencies.
  6. Check for a Dolphin `GameSettings/<DISCID>.ini` containing default DOL patches.
  7. Record hashes and extraction metadata.
- **Deliverables:** `GAME_IDENTIFICATION.md`, `DISC_MANIFEST.md`, `MODULE_INVENTORY.md`, `MODULE_DEPENDENCIES.md`.

### Phase 3 — Static recompilation pipeline

- **Tasks:**
  1. Recompile `main.dol` with the LLVM backend through `moderngekko-port`.
  2. Analyze `<ID>_fallbacks.csv` (fallbacks by reason) and `_smc.txt`.
  3. Determine which objects the module links (`.o` vs `.bc`) and whether IPO is effective.
  4. Measure static coverage.
  5. **If RELs exist:** design and implement REL recompilation, REL metadata emission into the module descriptor, and DOL+REL module merging (`TECHNICAL_ARCHITECTURE.md` §9).
- **Deliverables:** `RECOMPILATION_REPORT.md`, `CODE_COVERAGE.md`, build logs, list of unsupported instructions.

### Phase 4 — ModernGekko runtime integration

- **Tasks:**
  1. Load the module and confirm the `[staticrecomp] module loaded` line and the shutdown counters.
  2. Test `MODERNGEKKO_STATICRECOMP` behavior directly (the `staticrecomp:0/1` investigation). Keep three things separate:
     - module presence and validation;
     - permission to continue without a module (`--allow-interpreter`);
     - CPU-core selection.
     Confirm at runtime that `MODERNGEKKO_STATICRECOMP=0` does not bypass the module pre-check.
  3. Measure runtime fallback frequency.
  4. Confirm GPU selection (Intel vs llvmpipe), Vulkan and OpenGL rendering, audio backend, controller INI setup, file access, saves and timing.
- **Runtime-test environment:** decide between running on the host and a restricted test container (`BUILD_ENVIRONMENT.md` §7.4).
- **Deliverable:** `RUNTIME_INTEGRATION.md`.

### Phase 5 — Compatibility and verification

- Full game checklist, per the master prompt §6.
- Lockstep verification (`STATICRECOMP_LOCKSTEP`) for suspect code.
- **Deliverable:** `COMPATIBILITY_REPORT.md`.

### Phase 6 — Performance

- Compare against Dolphin under equivalent conditions.
- Investigate: the `x86-64-v3` target profile (the CPU supports it, per UPE), optimization level, PGO via `pgo-run`, the effect of fastmem being disabled, and InspectGame hashing cost on the HDD.
- **Deliverable:** `PERFORMANCE_REPORT.md`.

### Phase 7 — Gameplay modifications

- ModernGekko's code-mod ABI (`.mgm` packages).
- Port the earlier Gecko codes only after their addresses have been checked against the native module.
- **Caution:** runtime code patches invalidate chunk hashes and push that code to the fallback (SC).
- **Deliverable:** `MODDING_SYSTEM.md`.

### Phase 8 — Native PC application

- Branded build: `MODERNGEKKO_FRONTEND_NAME`, `MODERNGEKKO_DEFAULT_WINDOW_TITLE`, `MODERNGEKKO_REQUIRED_DISC_ID` and related options.
- The application must launch the recompiled runtime, never a plain emulator path.
- The Tournament Edition preparer branch must remain disabled.

### Phase 9 — Release preparation

- License review: GPL-3.0-or-later combined work, plus the bundled submodules.
- Module distribution model:
  - Upstream module-template documentation treats generated modules as derived works and instructs users not to redistribute them (VERIFIED as an upstream statement).
  - SR-ZGS adopts a conservative distribution policy in which users build modules from their own legally obtained game dumps, pending final legal review.
  - The final legal interpretation is part of this phase's license review. It has not been completed.
- Reproducible build and installation documentation.
- **Deliverable:** `RELEASE_NOTES.md`.

---

## 5. Risk register

The Classification column uses the evidence labels from `PROJECT_OVERVIEW.md` §1, not task statuses.

| # | Risk | Classification | Phase |
|---|---|---|---|
| R1 | No LLVM 19/20 installed | **Blocker** (UPE) | 1 |
| R2 | Toolchain newer than upstream CI (GCC 16, CMake 4.3, Python 3.14) | Potential risk, NOT TESTED | 1 |
| R3 | REL code not covered by the pipeline | Confirmed pipeline limitation (SC); game usage UNK | 2–3 |
| R4 | `--extract` rejects discs in a generic build; the disc ID must be known first | Confirmed (SC) | 2 |
| R5 | Extraction tools don't detect per-file failures | Confirmed (SC) | 2 |
| R6 | Self-modifying code / runtime patches force fallback | Confirmed upstream limitation (SC) | 3–4, 7 |
| R7 | Unsupported instructions and fallbacks | UNK until analyzed | 3 |
| R8 | Default DOL patches from a Dolphin `GameSettings` INI baked into native code | UNK | 2–3 |
| R9 | Unintended whole-game Jit64 execution, through two distinct paths. **(a) `--allow-interpreter`** with a missing or rejected module: the runtime clears the module configuration and continues without it. Without this option, a missing module stops startup and a rejected module is fatal. **(b) `MODERNGEKKO_STATICRECOMP=0`**: selects the JIT64 core **after** the module pre-check. It does not bypass module-required or validation checks and does not permit a missing or rejected module; a valid module may still pass validation but is not used for CPU execution. See `TECHNICAL_ARCHITECTURE.md` §4, §5.2, §6. Mitigation: native-path tests must use neither setting and must show the module-loaded log line and the native/fallback counters. | Confirmed behavior (SC) | 4 |
| R10 | Wrong GPU selected (llvmpipe), no audio backend, missing controller INIs | Potential risk, NOT TESTED | 4 |
| R11 | Floating-point / paired-single correctness | Potential risk | 3, 5 |
| R12 | Build memory and time on the HDD with 4 internal threads | Potential risk, unmeasured | 1, 3 |
| R13 | Upstream churn and stale revision labels | Confirmed (VERIFIED) | All |
| R14 | Redistribution of generated modules: upstream documentation instructs users not to redistribute them; SR-ZGS follows a conservative build-it-yourself policy; final legal interpretation pending | Upstream statement VERIFIED; legal interpretation pending (Phase 9) | 9 |
| R15 | The existing Toolbx container used by mistake as the build environment | Process risk | 1 |

---

## 6. Untested items carried forward

- Any build of DolRecomp, ModernGekko or RecompCore.
- LLVM 20 installation, and Fedora's static vs shared LLVM linking.
- CMake 4 compatibility of the bundled submodules; recursive shallow clone of the pinned commits.
- Launcher `--extract` with a required disc ID; `dolphin-tool`.
- Disc identification, REL inventory, `GameSettings` INI presence.
- Module loading, `MODERNGEKKO_STATICRECOMP` behavior, native/fallback counters.
- Wayland, PipeWire, PulseAudio and D-Bus connections; window creation; rendering; GPU selection; audio playback; input.
