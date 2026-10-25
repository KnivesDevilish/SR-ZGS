# =============================================================================
# src/core - SR:ZGS' own code that runs inside the game module.
#
# Phase 1 scope is deliberately tiny. Memory, CPU state, scheduling and the OS
# services all live in the ModernGekko chassis; what belongs HERE is the
# non-invasive way to change game behaviour: replacing individual guest
# functions (replacements.c) instead of editing src/recompiled/.
#
# Opt-in via -DSRZGS_ENABLE_REPLACEMENTS=ON. Off by default so the hot dispatch
# path stays untouched until the first real fix needs it.
# =============================================================================
if(NOT SRZGS_ENABLE_REPLACEMENTS)
  return()
endif()

add_library(srzgs_core OBJECT
  replacements.c)

target_include_directories(srzgs_core PRIVATE
  "${SRZGS_GENERATED_DIR}"        # generated.h (declares the dispatcher we implement)
  "${SRZGS_GXRUNTIME_INCLUDE}")   # core/cpu.h  (CPUState, u32, ...)

target_compile_definitions(srzgs_core PRIVATE
  DOLRECOMP_ENABLE_REPLACEMENTS
  DOLRECOMP_CPU_HEADER="core/cpu.h")

set_target_properties(srzgs_core PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  C_VISIBILITY_PRESET hidden)

if(NOT MSVC)
  target_compile_options(srzgs_core PRIVATE -Wall -Wextra)
endif()
