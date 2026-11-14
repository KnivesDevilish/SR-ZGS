# =============================================================================
# Sonic Riders: Source (SR-Source) - primary build, Phase 1
#
# What this builds: one native module per recompiled game,
# g<GAME_ID>_recomp.{so,dll}, made of
#   src/recompiled/  DolRecomp output (generated, never edited, not in git):
#                    src/recompiled/RS9E8P/ (Sonic Riders: Zero Gravity, Wii)
#                    and src/recompiled/GXEE8P/ (Sonic Riders, GameCube)
#   src/core/        our own hooks, linked into a module (opt-in)
# and stages them where the ModernGekko runner (the "chassis", built separately
# by tools/build_tools.sh --chassis) loads them from: it loads the module of
# the game being played. Video, audio, input and the GameCube and Wii services
# come from that chassis in Phase 1; src/platform/ only wires the modules to it.
#
#   tools/build_tools.sh && tools/dolrecomp/recompile.sh [GXEE8P]   (once / when a DOL changes)
#   cmake --preset release && cmake --build --preset release
# =============================================================================
cmake_minimum_required(VERSION 3.22)

project(SR_SOURCE
  VERSION 0.2.2
  DESCRIPTION "Sonic Riders: Source"
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
# The games: every one recompiled under src/recompiled/<GAME_ID>/ gets its
# module, unless SRZGS_GAMES names some.
set(SRZGS_GAMES "" CACHE STRING
  "Disc IDs to build modules for, ;-separated (empty: every game recompiled under src/recompiled/)")
# The game that srzgs_run, srzgs_preflight and src/core's replacements are for.
set(SRZGS_GAME_ID "RS9E8P" CACHE STRING
  "Disc ID of the game srzgs_run and srzgs_preflight start (RS9E8P Zero Gravity, GXEE8P Sonic Riders)")
set(SRZGS_CHASSIS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/external/ModernGekko" CACHE PATH
  "ModernGekko checkout (submodule; recursive)")
set(SRZGS_GAME_ROOT "" CACHE PATH
  "Extracted disc of SRZGS_GAME_ID, with sys/ and files/ (empty: game_assets if it is that game, else the one the launcher extracted)")
set(SRZGS_MODULE_OPT_LEVEL "2" CACHE STRING
  "Optimization level for the generated code (0-3). Use 1 for quick first-boot iterations.")
set_property(CACHE SRZGS_MODULE_OPT_LEVEL PROPERTY STRINGS 0 1 2 3)
option(SRZGS_ENABLE_REPLACEMENTS
  "Link src/core hooks so individual guest functions can be overridden" OFF)

# Which games have DolRecomp output: src/recompiled/<GAME_ID>/generated.h.
# CONFIGURE_DEPENDS: a game recompiled after configuring is picked up by the
# next build. Only six-character IDs count, so a half-written RS9E8P.new from
# an interrupted recompile.sh isn't taken for a game.
if(SRZGS_GAMES)
  set(SRZGS_GAME_IDS ${SRZGS_GAMES})
else()
  file(GLOB _srzgs_generated_headers CONFIGURE_DEPENDS
       "${CMAKE_CURRENT_SOURCE_DIR}/src/recompiled/*/generated.h")
  set(SRZGS_GAME_IDS)
  foreach(_srzgs_header IN LISTS _srzgs_generated_headers)
    get_filename_component(_srzgs_dir "${_srzgs_header}" DIRECTORY)
    get_filename_component(_srzgs_id "${_srzgs_dir}" NAME)
    # (CMake's regular expressions have no {6}.)
    if(_srzgs_id MATCHES "^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$")
      list(APPEND SRZGS_GAME_IDS "${_srzgs_id}")
    endif()
  endforeach()
  list(SORT SRZGS_GAME_IDS)
endif()
if(NOT SRZGS_GAME_IDS)
  message(FATAL_ERROR
    "No recompiled game under src/recompiled/. Run:\n"
    "  tools/dolrecomp/recompile.sh          (Sonic Riders: Zero Gravity, RS9E8P)\n"
    "  tools/dolrecomp/recompile.sh GXEE8P   (Sonic Riders, GameCube)")
endif()
message(STATUS "Game modules: ${SRZGS_GAME_IDS}")

set(SRZGS_MODULE_TARGETS)
foreach(_srzgs_id IN LISTS SRZGS_GAME_IDS)
  list(APPEND SRZGS_MODULE_TARGETS "g${_srzgs_id}_recomp")
endforeach()

# The game srzgs_run and srzgs_preflight start: SRZGS_GAME_ID, or the first
# one recompiled if it isn't. A normal variable, so it never changes the
# cached choice.
if(NOT SRZGS_GAME_ID IN_LIST SRZGS_GAME_IDS)
  list(GET SRZGS_GAME_IDS 0 _srzgs_first)
  message(STATUS "${SRZGS_GAME_ID} isn't recompiled: srzgs_run and srzgs_preflight start ${_srzgs_first}")
  set(SRZGS_GAME_ID "${_srzgs_first}")
endif()
set(SRZGS_GENERATED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/recompiled/${SRZGS_GAME_ID}")
set(SRZGS_MODULE_TARGET "g${SRZGS_GAME_ID}_recomp")

# ----------------------------------------------------------------------------
# Components - each directory owns exactly one concern
# ----------------------------------------------------------------------------
add_subdirectory(src/recompiled)   # generated game code  -> targets ${SRZGS_MODULE_TARGETS}
add_subdirectory(src/core)         # our hooks            -> target srzgs_core (if enabled)
add_subdirectory(src/platform)     # PC staging + launch  -> targets srzgs_stage, srzgs_run

# ----------------------------------------------------------------------------
# Assembly: the only place where the components meet.
# src/recompiled never learns about src/core; we attach the hooks from here.
# The hooks go into the module of SRZGS_GAME_ID (src/core is built for one game).
# ----------------------------------------------------------------------------
if(SRZGS_ENABLE_REPLACEMENTS)
  target_sources(${SRZGS_MODULE_TARGET} PRIVATE $<TARGET_OBJECTS:srzgs_core>)
  target_compile_definitions(${SRZGS_MODULE_TARGET} PRIVATE DOLRECOMP_ENABLE_REPLACEMENTS)
endif()
