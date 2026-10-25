# =============================================================================
# src/recompiled - DolRecomp output as a native game module.
#
# This directory holds NO hand-written game logic. The generated tree
# (src/recompiled/<GAME_ID>/, produced by tools/dolrecomp/recompile.sh and
# ignored by git because it is derived from the game binary) is built through
# the module template that ships with the pinned ModernGekko, so our build can
# never drift from the chassis' module ABI.
#
# Defines the SHARED target ${SRZGS_MODULE_TARGET} (= g<GAME_ID>_recomp).
# =============================================================================

set(_dolphin "${SRZGS_CHASSIS_DIR}/vendor/dolphin")

if(NOT EXISTS "${SRZGS_GENERATED_DIR}/generated.h")
  message(FATAL_ERROR
    "No recompiled output in ${SRZGS_GENERATED_DIR}\n"
    "Run: tools/dolrecomp/recompile.sh")
endif()
if(NOT EXISTS "${_dolphin}/module-template/CMakeLists.txt")
  message(FATAL_ERROR
    "ModernGekko module template not found under ${_dolphin}\n"
    "Run: git submodule update --init --recursive")
endif()

# Inputs of the upstream template. They must be CACHE entries: the template
# calls cmake_minimum_required(3.16), which resets policy CMP0126 to OLD inside
# its directory, so a plain variable of ours would be discarded by its own
# `set(<VAR> ... CACHE ...)` lines. INTERNAL keeps them out of the cache UI;
# our SRZGS_* options stay the only knobs.
set(GAME_ID                     "${SRZGS_GAME_ID}"         CACHE INTERNAL "")
set(GENERATED_DIR               "${SRZGS_GENERATED_DIR}"   CACHE INTERNAL "")
set(GXRUNTIME_DIR               "${_dolphin}/GXRuntime"    CACHE INTERNAL "")
set(CHASSIS_ABI_DIR             "${_dolphin}/Source/Core/Core/PowerPC/StaticRecomp" CACHE INTERNAL "")
set(RECOMPCORE_MODULE_OPT_LEVEL "${SRZGS_MODULE_OPT_LEVEL}" CACHE INTERNAL "")

add_subdirectory("${_dolphin}/module-template" "${CMAKE_CURRENT_BINARY_DIR}/module")

# Paths other components need to compile against the same generated code.
set(SRZGS_GXRUNTIME_INCLUDE "${GXRUNTIME_DIR}/include" CACHE INTERNAL "")
