# =============================================================================
# src/recompiled - DolRecomp output as native game modules.
#
# This directory holds NO hand-written game logic. Each generated tree
# (src/recompiled/<GAME_ID>/, produced by tools/dolrecomp/recompile.sh and
# ignored by git because it is derived from the game binary) is built through
# the module template that ships with the pinned ModernGekko, so our build can
# never drift from the chassis' module ABI.
#
# Defines one SHARED target per game in ${SRZGS_GAME_IDS}: g<GAME_ID>_recomp
# (gRS9E8P_recomp for Zero Gravity, gGXEE8P_recomp for Sonic Riders).
# =============================================================================

set(_dolphin "${SRZGS_CHASSIS_DIR}/vendor/dolphin")

if(NOT EXISTS "${_dolphin}/module-template/CMakeLists.txt")
  message(FATAL_ERROR
    "ModernGekko module template not found under ${_dolphin}\n"
    "Run: git submodule update --init --recursive")
endif()

foreach(_game IN LISTS SRZGS_GAME_IDS)
  set(_generated "${CMAKE_CURRENT_SOURCE_DIR}/${_game}")
  if(NOT EXISTS "${_generated}/generated.h")
    message(FATAL_ERROR
      "No recompiled output in ${_generated}\n"
      "Run: tools/dolrecomp/recompile.sh ${_game}")
  endif()

  # recompile.sh rewrites recomp.stamp on every run, so CMake then reads the
  # new output again: the template only looks at what was generated (C
  # chunks, or the LLVM backend's list of objects) when it is configured.
  if(EXISTS "${_generated}/recomp.stamp")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
      "${_generated}/recomp.stamp")
  endif()

  # Inputs of the upstream template, for this game. They must be CACHE
  # entries: the template calls cmake_minimum_required(3.16), which resets
  # policy CMP0126 to OLD inside its directory, so a plain variable of ours
  # would be discarded by its own `set(<VAR> ... CACHE ...)` lines. INTERNAL
  # keeps them out of the cache UI (our SRZGS_* options stay the only knobs)
  # and always overwrites, so each game's turn of the template sees its own.
  set(GAME_ID                     "${_game}"                  CACHE INTERNAL "")
  set(GENERATED_DIR               "${_generated}"             CACHE INTERNAL "")
  set(GXRUNTIME_DIR               "${_dolphin}/GXRuntime"     CACHE INTERNAL "")
  set(CHASSIS_ABI_DIR             "${_dolphin}/Source/Core/Core/PowerPC/StaticRecomp" CACHE INTERNAL "")
  set(RECOMPCORE_MODULE_OPT_LEVEL "${SRZGS_MODULE_OPT_LEVEL}" CACHE INTERNAL "")

  # Zero Gravity's module keeps the folder it always had (module/), so a
  # build made before there were two games doesn't compile it all again.
  if(_game STREQUAL "RS9E8P")
    set(_binary "${CMAKE_CURRENT_BINARY_DIR}/module")
  else()
    set(_binary "${CMAKE_CURRENT_BINARY_DIR}/module-${_game}")
  endif()
  add_subdirectory("${_dolphin}/module-template" "${_binary}")

  # A module made with DolRecomp's LLVM backend (BACKEND=llvm) calls
  # ppc_native_region_available(), which the pinned GXRuntime lacks: it gets
  # SR-Source's (see the file) until GXRuntime has its own.
  file(READ "${_generated}/generated.h" _generated_header)
  file(STRINGS "${_dolphin}/GXRuntime/src/core/cpu.c" _gxruntime_has_region_query
       REGEX "ppc_native_region_available")
  if(_generated_header MATCHES "DOLRECOMP_BACKEND_LLVM" AND NOT _gxruntime_has_region_query)
    target_sources("g${_game}_recomp" PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/native_region.c")
  endif()
endforeach()

# Paths other components need to compile against the same generated code.
set(SRZGS_GXRUNTIME_INCLUDE "${GXRUNTIME_DIR}/include" CACHE INTERNAL "")
