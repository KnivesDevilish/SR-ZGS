# =============================================================================
# Sonic Riders: Zero Gravity Source (SR:ZGS) - primary build, Phase 1
#
# What this builds: ONE native game module, g<GAME_ID>_recomp.{so,dll}, made of
#   src/recompiled/  DolRecomp output (generated, never edited, not in git)
#   src/core/        our own hooks, linked into the module (opt-in)
# and stages it where the ModernGekko runner (the "chassis", built separately
# by tools/build_tools.sh --chassis) loads it from. Video, audio, input and the
# Wii OS services come from that chassis in Phase 1; src/platform/ only wires
# the module to it.
#
#   tools/build_tools.sh && tools/dolrecomp/recompile.sh     (once / when the DOL changes)
#   cmake --preset release && cmake --build --preset release
# =============================================================================
cmake_minimum_required(VERSION 3.22)

project(SR_ZGS
  VERSION 0.1.0
  DESCRIPTION "Sonic Riders: Zero Gravity Source"
  LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# ----------------------------------------------------------------------------
# Project settings (override with -D<NAME>=<value>)
# ----------------------------------------------------------------------------
set(SRZGS_GAME_ID "RS9E8P" CACHE STRING
  "Six-character disc ID (Wii NTSC-U Sonic Riders: Zero Gravity)")
set(SRZGS_CHASSIS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/ModernGekko" CACHE PATH
  "ModernGekko checkout (submodule; recursive)")
set(SRZGS_GENERATED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/recompiled/${SRZGS_GAME_ID}" CACHE PATH
  "DolRecomp output staged by tools/dolrecomp/recompile.sh")
set(SRZGS_GAME_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/game_assets" CACHE PATH
  "Extracted disc root (must contain sys/ and files/)")
set(SRZGS_MODULE_OPT_LEVEL "2" CACHE STRING
  "Optimization level for the generated code (0-3). Use 1 for quick first-boot iterations.")
set_property(CACHE SRZGS_MODULE_OPT_LEVEL PROPERTY STRINGS 0 1 2 3)
option(SRZGS_ENABLE_REPLACEMENTS
  "Link src/core hooks so individual guest functions can be overridden" OFF)

set(SRZGS_MODULE_TARGET "g${SRZGS_GAME_ID}_recomp")

# ----------------------------------------------------------------------------
# Components - each directory owns exactly one concern
# ----------------------------------------------------------------------------
add_subdirectory(src/recompiled)   # generated game code  -> target ${SRZGS_MODULE_TARGET}
add_subdirectory(src/core)         # our hooks            -> target srzgs_core (if enabled)
add_subdirectory(src/platform)     # PC staging + launch  -> targets srzgs_stage, srzgs_run

# ----------------------------------------------------------------------------
# Assembly: the only place where the components meet.
# src/recompiled never learns about src/core; we attach the hooks from here.
# ----------------------------------------------------------------------------
if(SRZGS_ENABLE_REPLACEMENTS)
  target_sources(${SRZGS_MODULE_TARGET} PRIVATE $<TARGET_OBJECTS:srzgs_core>)
  target_compile_definitions(${SRZGS_MODULE_TARGET} PRIVATE DOLRECOMP_ENABLE_REPLACEMENTS)
endif()
