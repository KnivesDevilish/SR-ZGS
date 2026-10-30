# SR-ZGS — Technical Architecture

| Field | Value |
|---|---|
| Document version | 1.2 (Phase 0 closure synchronization) |
| Date | 2026-10-30 |
| Status | Source-level architecture only. **Nothing has been built or executed.** |
| Revisions described | The approved pin set (D1, approved 2026-10-30; "Option B" in `DEPENDENCIES.md`): ModernGekko `a2e4e2b`, RecompCore `cf8ceb8`, DolRecomp `71ce7f9`. Differences under Option A are noted where they matter. Full hashes are in `DEPENDENCIES.md`. |

Evidence labels are defined in `PROJECT_OVERVIEW.md` §1.

- Unless marked otherwise, statements here are **SC**: established by reading source at the revisions above, not observed at runtime.
- File references are relative to each repository's root. `RecompCore/` means ModernGekko's `vendor/dolphin` submodule.
- Template references are to ModernGekko-Template `c2553a9`.

---

## 1. Classification

SR-ZGS targets a **native recompilation runtime**: statically recompiled game code executed by a runtime that provides hardware compatibility.

In the inspected upstream design:
- Covered, hash-verified code runs **natively**, compiled ahead of time by DolRecomp.
- Uncovered code runs on the **Dolphin Jit64** fallback (a dynamic recompiler) while the StaticRecomp core is active.
- The runtime (RecompCore) is **Dolphin-derived**.
- Missing or rejected modules are handled by a runner pre-check (§5.2). They do not silently start the game on Jit64.

---

## 2. Upstream pipeline (as inspected)

| # | Stage | Component | Evidence |
|---|---|---|---|
| 1 | Developer supplies a disc image | — | — |
| 2 | Extraction to `extracted/<slug>/` | Template: `lib/DolRecomp` runs `dolrecomp extract`; for Wii discs it calls the external `wit` | Template `Makefile:150`; DolRecomp `src/frontend/container/disc_extract.c:677` (at `1bec355`) |
| 3 | Wii `DATA/` partition folder moved to the top level | Template Makefile | `Makefile:154-157` |
| 4 | Game inspection | `InspectGame()` | `ModernGekko/src/runtime/game.cpp:78-146` |
| 5 | Default DOL patches applied to a copy of `main.dol` | `moderngekko-port build` | `tools/moderngekko_port.cpp:580-581` |
| 6 | Static recompilation | Nested `dolrecomp` | `moderngekko_port.cpp:759-768` |
| 7 | Native module build | RecompCore `module-template` | `moderngekko_port.cpp` (configure/build step); `RecompCore/module-template/CMakeLists.txt` |
| 8 | Execution | `moderngekko-run` and the RecompCore StaticRecomp core | `tools/moderngekko_run.cpp`; `src/runtime/dolphin_runtime.cpp` |

### 2.1 Game inspection (stage 4)

`InspectGame()` performs these checks and reads:
- **Required files:** `<root>/sys/main.dol`, a `<root>/files/` directory, and a `<root>/sys/boot.bin` of at least 0x60 bytes.
- **Disc ID:** the first 6 bytes of `boot.bin`. Platform comes from the Wii magic `0x5D1C9EA3` at offset 0x18, or the GameCube magic `0xC2339F3D` at 0x1C.
- **DOL sanity:** validates the DOL section table and that the entry point lies in a text section.
- **Hashes:** SHA-256 of `main.dol`, `files/_Main.rel` if present, and the **entire `files/` tree**. This runs on every `inspect`, `build` and `run`; on the developer's mechanical HDD it is a measurable startup cost (TI).

### 2.2 Default DOL patches (stage 5)

- If `RecompCore/Data/Sys/GameSettings/<DISCID>.ini` exists, patches listed under `[OnFrame_Enabled]` are applied to `patched-main.dol` **before recompilation**.
- They are therefore baked into the native code. The patch fingerprint is part of the module cache key.
- Whether such an INI exists for the SR-ZGS disc ID is **UNK**; the disc ID itself is not yet known.

### 2.3 Recompilation (stage 6)

`moderngekko-port` runs:

```text
dolrecomp -j<hardware threads> --backend=<c|llvm> [--state-in-memory] \
  --cpu broadway <patched-main.dol> <DISCID> <output>
```

- **Not passed:** no `--runtime` option, no `--targets` (so the default host/generic target applies), and **no REL input**.
- **Which `dolrecomp` runs:** the one built from the **nested** `RecompCore/DolRecomp`, copied beside `moderngekko-port` by the custom target `moderngekko-port-recompiler` (`ModernGekko/CMakeLists.txt:624`).
  - The template's separate `lib/DolRecomp` is used only for `--setup` and `extract` (`Makefile:121`, `Makefile:150`).
- **Thread count:** taken from the hardware (4 on the developer's host). No `moderngekko-port` option changes it.
- **Outputs** (LLVM backend):
  - `generated.h`.
  - Per-chunk native `.o` objects and ThinLTO `.bc` bitcode, plus an object manifest.
  - `<ID>_fallbacks.csv`.
  - `<ID>_smc.txt`, normalized to `generated_smc.txt`.

### 2.4 Module build (stage 7)

- **Configure:** `cmake` on `RecompCore/module-template`, with `-G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=<gcc|clang> -DGAME_ID=<ID> -DGENERATED_DIR=… -DGXRUNTIME_DIR=… -DCHASSIS_ABI_DIR=…`. The build also uses the hardware thread count.
- **Python 3 is required** (`module-template/CMakeLists.txt:40`).
- **Output:** `g<DISCID>_recomp.so`.
- **Compiler choice:** `TOOLCHAIN=auto` selects the compiler family that built `moderngekko-port` (`moderngekko_port.cpp:589-598`). On the developer's GCC-based environments, that means GCC (TI).
- **Flags:**
  - GCC: `-O2 -ffp-contract=off -fno-fast-math`, no LTO.
  - Clang: interprocedural optimization only if CMake's IPO check passes. The template's own comments document a case where IPO was silently disabled.
- **Caution:** the `flags` string recorded in the module manifest is an identity string. It is **not** passed to the configure step. The manifest therefore does not prove which compiler or linker flags were applied.
- **Cache:** `<output>/<DISCID>/<dol-sha256>-<hash>/`, with `manifest.txt`. The key includes:
  - The hard-coded revision labels (see `DEPENDENCIES.md` §5).
  - Module and CPU ABI versions.
  - Compiler identity and the flags string.
  - Backend.
  - Patch fingerprint.
  - **SHA-256 of the `dolrecomp` binary.**
  - PGO identity and selected `DOLRECOMP_*` environment variables.

---

## 3. Who executes what (Rule 3)

| Question | Answer | Label |
|---|---|---|
| What executes game CPU code? | With the default StaticRecomp core and an active module: the native module for covered, hash-verified chunks, and **Dolphin Jit64** for uncovered chunks. Three separate mechanisms, applied in this order: (1) **module pre-check**: a missing module is rejected and a rejected module is **fatal**, unless `--allow-interpreter` is given (§5.2); (2) **`--allow-interpreter`**: permits continuing without the module, on Jit64; (3) **CPU-core selection**, after the pre-check: `MODERNGEKKO_STATICRECOMP=0` selects JIT64, which does not use the native module for CPU execution and does not bypass the pre-check (§4). | SC |
| What provides hardware compatibility? | RecompCore (Dolphin-derived): video, audio/DSP, input, Wii OS high-level emulation, disc I/O, timing | SC |
| What is statically recompiled? | `main.dol` code ranges only, in the template pipeline | SC |
| What uses fallback execution? | See §6 | SC |
| What originates from Dolphin? | Everything under `vendor/dolphin` (RecompCore) and `vendor/dolphin_legacy` | VERIFIED |

---

## 4. CPU core selection

- **CPU core enum** (`RecompCore/Source/Core/Core/PowerPC/PowerPC.h:35-43`):

  | Value | Core |
  |---|---|
  | 0 | Interpreter |
  | 1 | JIT64 |
  | 4 | JITARM64 |
  | 5 | CachedInterpreter |
  | 6 | **StaticRecomp** |

  The source comment describes the StaticRecomp core as using an "interpreter fallback". On x86-64, the code actually creates a **Jit64** fallback (`StaticRecompCore.cpp:191`).

- **Runtime selection** (`ModernGekko/src/runtime/dolphin_runtime.cpp:98-110`):
  - The environment variable `MODERNGEKKO_STATICRECOMP` decides the core.
    - Unset, empty, or not starting with `0`: the StaticRecomp core.
    - Starting with `0`: JIT64 on x86-64. CPU execution is then pure Dolphin dynamic recompilation, and the native module is not used.
  - The choice is written to Dolphin's base configuration layer (line 660). Whether a game-specific INI layer could override it is **UNK**.
- **Ordering relative to the module pre-check** (SC at `a2e4e2b`):
  - `Runtime::Create()` (`dolphin_runtime.cpp:549`) performs the module-required and module-validation pre-check (lines 564-592, §5.2) **before** it calls `SelectCPUCore()` (line 660).
  - `MODERNGEKKO_STATICRECOMP=0` therefore does **not** bypass the pre-check. Without `--allow-interpreter`, a missing module still stops startup and a rejected module is still fatal, even when JIT64 is selected. The variable does not grant permission to run without a module; only `--allow-interpreter` does.
  - If a valid module is supplied, it can still pass validation while JIT64 is selected. The runtime still hands the module source to the JIT interface (line 708). However, `JitInterface` constructs `Jit64` for the JIT64 core and passes the module source only to `StaticRecompCore` (`RecompCore/Source/Core/Core/PowerPC/JitInterface.cpp:59-60, 72-73`). The native module is therefore not used for CPU execution under JIT64.

- **`[Core]` configuration keys** (`RecompCore/Source/Core/Core/Config/StaticRecompSettings.cpp`):

  | Key | Type / default | Notes |
  |---|---|---|
  | `StaticRecompModule` | bool, default true | **No reader found** in `Source/Core/Core`, `UICommon`, `DolphinNoGUI` or ModernGekko. Apparently inert at this revision. |
  | `StaticRecompIdlePC` | address | Idle-loop address |
  | `StaticRecompFallbackRanges` | address ranges | Can be overridden by the `STATICRECOMP_FALLBACK_RANGES` environment variable (`StaticRecompCore.cpp:150-153`) |

- **The previous attempt's `staticrecomp:0` / `staticrecomp:1`.** These most likely corresponded to `MODERNGEKKO_STATICRECOMP=0` (JIT64 only) versus the StaticRecomp core (TI). The exact setting used was not supplied. Under that reading, the `0` runs would still have needed a valid module, or `--allow-interpreter`, to get past the startup pre-check (see the ordering above).

---

## 5. Native module loading and validation

### 5.1 Module discovery (`moderngekko_run.cpp:164-165, 325-336`)

The runner looks in this order:
1. The `--module <path>` argument. `moderngekko-port run` always passes this.
2. The `STATICRECOMP_MODULE` environment variable.
3. A file named `g<ID>_recomp.so` beside the runner.
4. `<user-dir>/StaticRecompModules/g<ID>_recomp.so`.

### 5.2 Runner pre-checks (`Runtime::Create()`, `dolphin_runtime.cpp:549`; checks at lines 564-592)

- **Order:** these checks run **before** CPU-core selection (§4). `MODERNGEKKO_STATICRECOMP` does not bypass them.
- **Missing module:** with no module and no `--allow-interpreter`, the runner refuses to start ("no native module was supplied").
- **Rejected module:** a module that fails to load or fails validation is a fatal error ("native module was rejected"), unless `--allow-interpreter` is given.
- **With `--allow-interpreter` after a rejection:** the runtime clears the module configuration (`config.module = {}`, line 590) and the game continues **without** the module, on Jit64.
- The pre-check calls `moderngekko_validate_module()` (`ModernGekko/src/runtime/module.cpp:106`). It checks:
  - Module ABI version, CPU ABI version and `CPUState` size.
  - Game ID validity, and a match with the disc's ID.
  - Dispatch function, code ranges and self-modifying-code ranges.
  - Chunk tiling.
  - REL metadata.
  - Entry-point coverage.
- These mirror the core's own checks in §5.3, so a module that passes the pre-check is expected to pass `LoadModule()` as well (TI).

### 5.3 Module validation (`StaticRecompCore::LoadModule()`, `StaticRecompCore.cpp`)

The core rejects a module when any of the following is true:
- The `staticrecomp_get_module` export is missing.
- The module ABI version, CPU ABI version, or `CPUState` size doesn't match.
- There is no dispatch function, or the code ranges are empty.
- The game ID is invalid, or doesn't match the running game.
- Code or self-modifying-code ranges are malformed or overlapping.
- Chunk ranges or hashes are missing, or the chunks don't exactly tile the code ranges.
- REL metadata is malformed.
- The entry point is not covered by the module.

### 5.4 Execution (`StaticRecompCore_Run.cpp`)

- When the current address falls in a **verified** chunk, execution is dispatched to native code.
- Otherwise the Jit64 fallback runs (line 252).
- If no module is active, the entire `Run()` is delegated to Jit64 (lines 114-117). In the `moderngekko-run` path this is reached when:
  - the runner was started with `--allow-interpreter` and the module was missing or rejected, or
  - the running game's ID no longer matches the module's game ID. The core re-evaluates `m_module_active` on every loop iteration.
- Chunk hashes are checked against guest RAM. This is the self-modifying-code guard: modified code falls back.
- Dolphin's fastmem is disabled in this core (`StaticRecompCore.cpp:163`), which may matter for performance (Phase 6).

---

## 6. Fallback conditions

**While the StaticRecomp core runs with an active module**, code runs on the Dolphin Jit64 fallback instead of native code when any of these apply:

1. DolRecomp marked the instruction as a fallback. Reasons: `embedded-data`, `unknown`, `exception-boundary` (`sc`, `rfi`) or `unsupported`.
2. The address is outside the module's code ranges. This includes all REL code in the current pipeline (§9).
3. The chunk's hash no longer matches guest RAM: self-modifying code, runtime patches, or cheat codes.
4. The address lies in `StaticRecompFallbackRanges`. Some games ship large ranges; for example `Data/Sys/GameSettings/SUKE01.ini`.

**Whole-game Jit64 execution** (no native module in use) occurs only in these cases:

5. The runner was started with `--allow-interpreter` and the module was missing or rejected; the runtime cleared the module configuration (§5.2). **Without** that option, a missing module stops startup and a rejected module is a fatal error. Neither case silently falls back to Jit64.
6. The running game's ID changes so that it no longer matches the module (§5.4).
7. `MODERNGEKKO_STATICRECOMP=0` selected the JIT64 core instead of StaticRecomp (§4).
   - This selection happens only **after** the module pre-check. It does not permit a missing or rejected module: without `--allow-interpreter`, those still stop startup.
   - A valid module can pass validation in this case but is not used for CPU execution.

None of these cases is acceptable as evidence of native execution. Native-path tests must not use `--allow-interpreter` or `MODERNGEKKO_STATICRECOMP=0`, and must meet the evidence rule in §7.

---

## 7. Evidence signals and diagnostics

**All NOT TESTED.**

| Signal | Source | What it shows |
|---|---|---|
| `[staticrecomp] core init` | `StaticRecompCore.cpp:181` | The StaticRecomp core was selected |
| `[staticrecomp] module loaded: <path> entry=0x…` | `StaticRecompCore.cpp:342` | A module passed validation |
| `StaticRecomp: no explicit module source; interpreter-only.` | `StaticRecompCore.cpp:246` | No module was supplied. In `moderngekko-run`, only reachable with `--allow-interpreter` (§5.2). Despite the wording, the core then runs on Jit64. |
| `StaticRecomp: rejecting module '…': <reason>` | `StaticRecompCore.cpp` (`LoadModule`) | A module was rejected |
| `[staticrecomp] shutdown: native=… fallback=… native_exc=… hook_fb=… smc_failed=… …` | `StaticRecompCore.cpp:205` | Counts of native vs fallback execution |
| `<ID>_fallbacks.csv` with columns `address,raw,opcode,reason,detail` | DolRecomp `src/app/pipeline.c` | Static list of fallback points |
| `STATICRECOMP_DISPATCH_SAMPLES` | `StaticRecompCore.cpp:150` | Prints the top dispatch sites at shutdown |
| `STATICRECOMP_TRACE_FILE=<path>` | `StaticRecompCore_Run.cpp:37` | Writes a dispatch trace CSV |
| `STATICRECOMP_LOCKSTEP`, plus `_START`, `_LIMIT`, `_FILTER` and others | `StaticRecompLockstep.cpp:52-85` | Lockstep correctness verification of native code against fallback execution |

**Project rule.** A run counts as evidence of native execution only when:
- the module-loaded line appears, **and**
- the shutdown counters show native dispatches.

Coverage claims additionally require the fallback counters and the static fallback report.

---

## 8. DolRecomp and LLVM

- **How LLVM is used:**
  - As a C++ library, in-process, via `find_package(LLVM CONFIG)`.
  - Components: `Core Support Analysis BitWriter Passes Target MC native nativecodegen`, plus `X86CodeGen X86AsmParser`. If LLVM's CMake package provides the shared `LLVM` library target, that is linked instead.
  - No LLVM command-line tools are invoked for code generation, and there is no LLVM dependency at runtime.
- **Version check:** `CMakeLists.txt:10-16` rejects anything outside `19 <= version < 21` (VERIFIED). DolRecomp's CI tests LLVM 20.
- **Code generation:**
  - Per-chunk native objects are generated at optimization level 3, alongside ThinLTO bitcode.
  - Which of the two the module actually links is decided by the generated manifest. **UNK** until a module is generated.
- **Target profiles** (`src/backend/llvm/target.cpp`):
  - `host` means the host triple with CPU **`generic`** (line 28). It is not `-march=native`.
  - Other profiles: `x86-64-v2`, `x86-64-v3`, `aarch64`, `aarch64-a57`.
  - `moderngekko-port` passes no `--targets`, so it gets host/generic. The developer's CPU supports x86-64-v3 (UPE), but using it is a Phase 6 question.
- **Floating point:** `--semantics exact` is the default, with strict floating-point operation fusion. The module's C code is compiled with `-ffp-contract=off -fno-fast-math`.

**Command-line options by revision** (VERIFIED from `src/app/cli.c`):

| Option | `1bec355` (Option A) | `71ce7f9` (Option B) | `02e27ac` (main HEAD) |
|---|---|---|---|
| `--backend`, `--cpu`, `--targets`, `--semantics`, `--rel-base`, `--map`, `--instrumentation`, `--state-in-memory`, `-j` / `--jobs` | ✓ | ✓ | ✓ |
| `--runtime`, `--native-abi`, `--game-id` | ✗ | ✓ | ✓ |
| `--range-profile*`, `--config`, `--native-entry-points` | ✗ | ✗ | ✓ |

**The `--runtime=moderngekko` native-module mode.**
- Its emitter is `src/backend/native_module.c`, present from `71ce7f9`.
- No consumer of its interface was found in any of these:
  - ModernGekko master.
  - RecompCore `cf8ceb8` (`Source/Core/Core`, `GXRuntime`).
  - The PowerPC and GXRuntime source paths of RecompCore's `main` and `moderngekko-runtime` branches.
- SR-ZGS does not use it. The README's reference command `dolrecomp --backend=llvm --runtime=moderngekko --targets host …` is **not** the supported pipeline.

**Title database.**
- DolRecomp reads `database/titles.txt` relative to the current working directory.
- If the file is missing, a Wii input is treated as "titleless/GameCube mode" (`src/app/main.c:62-65`).
- Because `--cpu broadway` is passed explicitly, the effect should be limited to output naming (TI), and `moderngekko-port` accepts both naming forms.

---

## 9. DOL/REL assessment

1. **Only `main.dol` is recompiled** by the template pipeline (`moderngekko_port.cpp:759-768`).
2. **DolRecomp can recompile RELs** (at `71ce7f9`):
   - A single REL or a whole folder.
   - Default virtual load address `0x80500000` (`REL_AUTO_BASE`, `src/app/pipeline.h:12`); `--rel-base` overrides it.
   - Self-relocations are applied.
   - Imports between RELs compiled together are resolved.
   - Imports from `main.dol` (module 0) resolve to absolute addresses (`src/frontend/container/rel.c:165-168`).
   - Imports from a module not in the same run are an error (`rel.c:170-176`).
3. **No way to merge DOL and REL output.** `module-template` takes a single generated directory. Nothing in the inspected pipeline combines DOL and REL output into one module.
4. **The runtime does support RELs.**
   - The module descriptor has `rel_modules` and `num_rel_modules` fields (`StaticRecompABI.h:89-90`).
   - `LoadModule()` validates that metadata.
   - `StaticRecompCore::RefreshRelSections()` scans guest RAM for loaded REL headers and maps their sections back to the addresses they were compiled at (`StaticRecompCore_SMC.cpp:21-100`).
5. **Nothing produces the REL metadata.**
   - `module-template/module_export.c:92-107` initializes the descriptor only up to `chunk_hashes`, so `rel_modules` is null and `num_rel_modules` is 0.
   - Neither DolRecomp pin (`1bec355`, `71ce7f9`) emits REL metadata.
   - The runtime's REL remapping is therefore never activated in this pipeline.
6. **Consequence:** REL code is **not covered** by the current template pipeline. It would run on Jit64 (TI, strongly supported by points 1, 3 and 5).
7. **`_Main.rel` is only hashed.** `InspectGame` hashes `files/_Main.rel` for identity and never recompiles it.
8. **Game-specific facts are UNK until Phase 2:** whether *Sonic Riders: Zero Gravity* uses RELs, how many, their load order and their dependencies.
9. **What full coverage would require**, if the executable inventory needs it (a Phase 3 engineering task):
   - Recompile RELs at addresses consistent with the runtime's remapping.
   - Emit REL metadata into the module descriptor.
   - Merge DOL and REL objects into one module.
   - Whether to build this as SR-ZGS-owned tooling or as an upstream contribution is undecided.

---

## 10. Disc extraction

### 10.1 Required layout

`InspectGame()` and `moderngekko-port` need a flat game root containing `sys/main.dol`, `sys/boot.bin` and `files/` (§2.1).

### 10.2 ModernGekko launcher (`ModernGekko/tools/moderngekko_launcher.cpp`) — D3 primary candidate

The launcher source is identical at `edd460a` and `a2e4e2b` (VERIFIED). It has four distinct parts.

**(a) GUI application.**
- After argument parsing, `main()` loads `config.ini`, initializes SDL video, creates a window and runs ImGui (from about line 533).
- Build target: `moderngekko-launcher`, output name `ModernGekko` by default (`CMakeLists.txt:29, 516, 543`). It depends on `moderngekko-run` (line 601).
- The template does **not** build it; it builds only `--target moderngekko-port` (`Makefile:113`).

**(b) Command-line extraction-only mode.**
- **Syntax:** `<launcher> --extract <disc-image>` (lines 507-515).
- **Behavior:** handled before any configuration loading or SDL initialization (lines 519-531).
  - Success: prints `<status>: <path>` to stdout and exits **0**.
  - Failure: prints `extraction failed: <error>` to stderr and exits **1**.
- **Quirk:** if `--extract` is the last argument with no value, it is ignored and the GUI starts.
- **Output location:** there is **no** output-directory option. Output always goes to `<user-dir>/games/<DISCID>` (line 386).
  - `<user-dir>` is `$XDG_DATA_HOME/<name>`, otherwise `$HOME/.local/share/<name>` (lines 135-155).
  - `<name>` comes from `MODERNGEKKO_USER_DIRECTORY_NAME`, default `moderngekko` (`CMakeLists.txt:33`).
  - With `MODERNGEKKO_PORTABLE_DEFAULT_GAME`, output goes to `<launcher dir>/Game` instead.

**(c) `ExtractDisc()`** (lines 345-478).
- **Steps:**
  1. Calls `PrepareDisc()`.
  2. Selects the game partition (line 369).
  3. Rejects the disc if a required disc ID is compiled in and doesn't match (lines 377-381).
  4. Extracts into a staging folder `<games>/<ID>.extracting` (line 410).
  5. Exports system data and **checks the result** (line 420).
  6. Exports all game files into `files/` (line 431).
  7. Applies a bundled DOL patch, but **only** if `MODERNGEKKO_DOL_PATCH_MANIFEST` is defined; otherwise it does nothing (lines 189-205).
  8. Validates with `InspectGame()` and the optional hash checks (lines 449-459 and 83-102).
  9. Publishes by renaming the staging folder (line 464).
- **Side effects:**
  - Writes `default-game.txt` into the user directory.
  - **Deletes any existing `games/<ID>` folder before publishing** (line 462, `remove_all(output)`).
  - **Reuses existing output** in `games/<ID>` (lines 390-407).
    - If a DOL patch manifest is configured, it is first applied to the existing extraction (lines 390-396).
    - The output is reused when `InspectGame()` passes and `RequiredGameError()` reports no failure against the configured identity and hash requirements (lines 397-407).
    - `InspectGame()` checks the required layout and DOL structure and calculates hashes.
    - `RequiredGameError()` checks the disc ID and, **only if configured**, the expected DOL, `_Main.rel` and assets SHA-256 pins (lines 83-102).
    - **Without expected hash pins, this does not establish byte-for-byte identity with the source disc.** Independent completeness and provenance checks remain necessary in Phase 2 (§10.5).
- **Remaining gap:** per-file export failures are **not** detected, because the underlying directory export only logs them (`RecompCore/Source/Core/DiscIO/DiscExtractor.cpp:124-127`).

**(d) `PrepareDisc()`** (lines 282-342). Its behavior is set entirely at compile time:

| Build configuration | Result |
|---|---|
| **Generic build** (`MODERNGEKKO_REQUIRED_DISC_ID` empty) | Always fails with "this disc is not the pinned patched release" (lines 339-341). **`--extract` cannot succeed in a generic build.** |
| `MODERNGEKKO_REQUIRED_DISC_ID=<ID>` set, no preparer | A disc whose game-partition ID equals `<ID>` is accepted (lines 293-295); any other disc is rejected |
| `MODERNGEKKO_DISC_PREPARER_OUTPUT_NAME` + `MODERNGEKKO_ACCEPTED_SOURCE_DISC_ID` + `MODERNGEKKO_REQUIRED_DISC_ID` all set | Sonic Riders **Tournament Edition 2.4.6.1** branch: writes `<user-dir>/Setup/SonicRidersTE-2.4.6.1.iso` and runs an external patcher (lines 297-338). **Unrelated to SR-ZGS; must remain disabled.** |

**Adaptation required for SR-ZGS.** No source change appears necessary for the basic path (SC), but all of the following are needed:

1. **Determine the game's disc ID first.**
   - This happens in Phase 2, through a read-only identification step whose method is still to be decided.
   - Candidates:
     - `dolphin-tool header -i <image>`, which prints the game ID, region and revision (`HeaderCommand.cpp`). This requires building `dolphin-tool`.
     - Reading the unencrypted disc header of a plain `.iso` (TI; plain ISO only).
   - The disc ID must not be assumed.
2. **Configure with `-DMODERNGEKKO_REQUIRED_DISC_ID=<ID>`.**
   - Leave `MODERNGEKKO_DISC_PREPARER_OUTPUT_NAME` and `MODERNGEKKO_ACCEPTED_SOURCE_DISC_ID` empty.
   - The same definition also locks `moderngekko-run` to that disc ID: any other disc exits with code 2 (`moderngekko_run.cpp:295-301`). This fits a single-game product, but it must be a deliberate choice.
3. **Build `moderngekko-launcher` explicitly.**
4. **Isolate the output.**
   - Run extraction with a dedicated, empty user directory, for example by pointing `XDG_DATA_HOME` at an isolated folder. That this works follows from the lookup order in lines 135-155 (TI).
   - This keeps the `remove_all` at line 462 away from real data.
5. **Optionally pin hashes** with `MODERNGEKKO_REQUIRED_DOL_SHA256` and `MODERNGEKKO_REQUIRED_ASSETS_SHA256` once Phase 2 has recorded them.
6. **Add an independent completeness check** (§10.5).

Status: **NOT TESTED.** The generic build has not been shown to accept the SR-ZGS disc, and source inspection says it will not.

### 10.3 `dolphin-tool` — alternative

- **Build target:** `dolphin-tool` (`RecompCore/Source/Core/DolphinTool/CMakeLists.txt:1-12`).
  - Enabled by `MODERNGEKKO_ENABLE_DISC_TOOL=ON`, default OFF (`ModernGekko/CMakeLists.txt:25-26, 97`).
  - Because ModernGekko adds the Dolphin tree with `EXCLUDE_FROM_ALL` (line 124), the target must be built explicitly (TI from CMake semantics).
- **Commands:** `convert`, `verify`, `header`, `extract` (`ToolMain.cpp:21-54`).
  - `extract -i <image> -o <dir> [-p <partition>] [-s <path>] [-l] [-q] [-g]` (`ExtractCommand.cpp:221-248`). `-g` extracts only the DATA partition.
- **Formats and decryption:**
  - Accepts Wii and GameCube discs; rejects WADs and bare ELF/DOL files (lines 44-62).
  - Image formats come from Dolphin's disc-image layer: plain ISO, WBFS, GCZ, CISO, WIA, RVZ and others (`DiscIO/Blob.h:31-45`).
  - Wii partitions are decrypted in-process (`DiscIO/VolumeWii.cpp:137`).
- **Output layout:** `<dir>/<PARTITION>/files/…` plus `<dir>/<PARTITION>/sys/{boot.bin, bi2.bin, apploader.img, main.dol, fst.bin}`.
  - Wii discs also get `disc/{header.bin, region.bin}`, `ticket.bin`, `tmd.bin`, `cert.bin`, and `h3.bin` when present (`DiscExtractor.cpp:301-327`).
  - Partition folders are named `DATA`, `UPDATE`, `CHANNEL`, or `P-<id>` (`DiscUtils.cpp:23-50`).
  - The template's existing `DATA/` flattening step would apply.
- **Weak error handling.** Exit code 0 does **not** prove a complete extraction:
  - The system-data export result is discarded (`ExtractCommand.cpp:95`).
  - A full partition extract reports success unconditionally (lines 189-192).
  - Existing files are silently skipped (`DiscExtractor.cpp:124-125`).
  - A partition whose type can't be read is skipped (line 349).
  - The root lookup result is used without a null check (lines 71-72).
- **Network access:** none found in the extract path. `verify` passes `redump_verification=false` (`VerifyCommand.cpp:157`), so it downloads nothing.
- **`verify` side effects:** it initializes a Dolphin user directory (lines 105-106), creating a default one unless `--user` is given. It also returns success even when problems are found (line 196).
- **Usage:** no upstream component uses or builds it.

### 10.4 Template `wit` route

- `dolrecomp --setup`, run automatically as `echo y | dolrecomp --setup` (`Makefile:121`), downloads `https://wit.wiimm.de/download/wit-v3.05a-r8638-x86_64.tar.gz` (`setup.c:26`) **without checksum verification**, then extracts and marks it executable.
- Extraction runs `wit EXTRACT -o <in> <out>` (`disc_extract.c:677` at `1bec355`).
- Usable only with explicit developer approval and a pinned checksum.

### 10.5 Comparison and required validation

| | Launcher `--extract` | `dolphin-tool extract -g` | Template `wit` |
|---|---|---|---|
| Where it comes from | Built from pinned source | Built from pinned source | Prebuilt binary downloaded without a checksum |
| Works in a generic build? | **No**; needs a disc ID compiled in | Yes | Yes |
| Output layout | Flat (`sys/`, `files/`) | `DATA/…`, needs flattening | Per-partition, needs flattening |
| System-data errors | Checked | Ignored | wit's exit code (behavior UNK) |
| Per-file errors | Not detected | Not detected | UNK |
| Validates with `InspectGame` | Yes | No | No (the template runs it later) |
| Destructive behavior | `remove_all(output)` | Skips existing files | Template `clean` targets |
| Network access | None | None | Download during `--setup` |
| Used upstream? | Yes (ModernGekko launcher) | No | Template's documented route |

**Required validation regardless of tool (Phase 2):**
- Extract into an empty, isolated folder.
- Compare the disc's own file listing (for example `dolphin-tool extract -l -p data`) against the extracted tree, by count and by names.
- Confirm the required `sys/` files exist and are non-empty.
- Run `moderngekko-port inspect`.
- Record SHA-256 hashes.
- Compare the disc's hash against an independently obtained reference.

---

## 11. Runtime services

**All SC, all NOT TESTED.**

- **Graphics:**
  - Default backend `Vulkan` on Linux when not headless (`moderngekko_run.cpp:345`). `--graphics` overrides it; headless uses `Null`.
  - Shader cache on, asynchronous ubershaders, and waiting for shaders before starting (`dolphin_runtime.cpp`, around lines 661-689).
  - Which GPU is selected (the Intel integrated GPU vs llvmpipe): **NOT TESTED**.
- **Windowing:**
  - The Wayland platform is compiled when `wayland-client` is found; the X11 platform when X11 is found.
  - SDL3 is bundled (`USE_SYSTEM_SDL3=OFF`).
- **Audio:**
  - Cubeb is disabled on Linux by ModernGekko's CMake.
  - Runtime preference is Cubeb → PulseAudio → ALSA → NullSound (`dolphin_runtime.cpp`, same region).
  - A backend exists only if its development headers were present at build time.
- **Input:**
  - No in-app controller configuration.
  - Bindings come from `Config/GCPadNew.ini` and `Config/WiimoteNew.ini` in the user directory, which nothing creates (template README).
  - Wii builds default to Wii Remote profiles unless `MODERNGEKKO_GAMECUBE_CONTROLLERS` is set.
- **Mods:** `<id>.mgm` packages from `Mods/` (ModernGekko README). Phase 7.

---

## 12. Dolphin-derived components

- **RecompCore (the entire `vendor/dolphin`):**
  - Core: PowerPC, including Jit64 and the StaticRecomp core; hardware; Wii OS high-level emulation; DSP.
  - VideoCommon and the video backends.
  - AudioCommon, InputCommon, DiscIO, UICommon.
  - DolphinNoGUI platform code.
  - `Data/Sys`.
- **ModernGekko `vendor/dolphin_legacy`:** Common, a subset of Core, VideoBackends, VideoCommon.
- **ModernGekko-owned code:** `src/`, `tools/`, `include/`, `tests/`, `mod-template/`.

---

## 13. Open architectural questions

1. How to cover REL code if the game uses RELs (§9).
2. Whether the module links the native `.o` objects or the ThinLTO `.bc` bitcode, and whether IPO is actually applied (§2.4, §8).
3. Whether Fedora's `llvm20-devel` provides the shared `LLVM` library target or only component libraries.
4. Compatibility with GCC 16.2.1, CMake 4.3.0 and Python 3.14.x.
5. Upstream direction of the `--runtime=moderngekko` native-module mode.
6. Whether a game-specific INI can override the CPU core selection.
7. Whether a Dolphin `GameSettings/<DISCID>.ini` with default DOL patches exists for the SR-ZGS disc.
8. Which read-only disc-identification method to use before a launcher build with `MODERNGEKKO_REQUIRED_DISC_ID`.
