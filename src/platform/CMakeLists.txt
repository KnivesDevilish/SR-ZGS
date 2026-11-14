# =============================================================================
# src/platform - PC platform glue (Linux / Windows), Phase 1.
#
# The ModernGekko chassis already provides video (Vulkan/OpenGL), audio, input
# and the Wii OS services, so nothing here reimplements them. This directory
# only (a) stages the built modules, (b) seeds the runtime user directory and
# (c) launches the runner. Our own renderer/audio backends would live here in
# later phases.
#
# Targets:
#   srzgs_stage         copy every game's module to <build>/stage and beside
#                       the runner (part of ALL)
#   srzgs_preflight     check disc layout, DOL/module/runner coherence (Linux)
#   srzgs_run           launch SRZGS_GAME_ID with its module (runs preflight first)
#   srzgs_run_baseline  launch WITHOUT our module: chassis/disc/GPU sanity check
#
# Cache options: SRZGS_USER_DIR, SRZGS_RUN_ARGS, SRZGS_RUNNER, SRZGS_CHASSIS_BUILD_DIR
# =============================================================================

set(SRZGS_STAGE_DIR "${CMAKE_BINARY_DIR}/stage")

set(SRZGS_CHASSIS_BUILD_DIR "${CMAKE_SOURCE_DIR}/build/chassis" CACHE PATH
  "Build tree of the chassis made by tools/build_tools.sh --chassis")

# Every game's module, to <build>/stage and beside moderngekko-run, where the
# runner finds the one of the game being played (g<disc ID>_recomp).
set(_srzgs_stage_copies)
foreach(_srzgs_module IN LISTS SRZGS_MODULE_TARGETS)
  list(APPEND _srzgs_stage_copies
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:${_srzgs_module}>" "${SRZGS_STAGE_DIR}"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:${_srzgs_module}>" "${SRZGS_CHASSIS_BUILD_DIR}")
endforeach()
add_custom_target(srzgs_stage ALL
  COMMAND ${CMAKE_COMMAND} -E make_directory "${SRZGS_STAGE_DIR}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${SRZGS_CHASSIS_BUILD_DIR}"
  ${_srzgs_stage_copies}
  COMMENT "Staging the game modules: ${SRZGS_MODULE_TARGETS}"
  VERBATIM)
add_dependencies(srzgs_stage ${SRZGS_MODULE_TARGETS})

# --- runtime user directory (config.ini, controller profile, saves, logs) -----
# Outside the repo so `rm -rf build` never deletes saves, and separate from any
# other ModernGekko-based game on the machine.
if(WIN32)
  set(_srzgs_default_user "$ENV{LOCALAPPDATA}/sr-source")
elseif(NOT "$ENV{XDG_DATA_HOME}" STREQUAL "")
  set(_srzgs_default_user "$ENV{XDG_DATA_HOME}/sr-source")
else()
  set(_srzgs_default_user "$ENV{HOME}/.local/share/sr-source")
endif()
set(SRZGS_USER_DIR "${_srzgs_default_user}" CACHE PATH "Runtime user directory")
set(SRZGS_RUN_ARGS "" CACHE STRING
  "Extra moderngekko-run arguments, ;-separated (e.g. \"-X11\" or \"--wayland;--mute\")")
set(SRZGS_RUNNER "" CACHE FILEPATH
  "moderngekko-run override (default: located when the target runs)")

# Seed the config once. Never overwrite: the user's edits win.
if(NOT EXISTS "${SRZGS_USER_DIR}/config.ini")
  file(MAKE_DIRECTORY "${SRZGS_USER_DIR}")
  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/config/config.ini"
                 "${SRZGS_USER_DIR}/config.ini" COPYONLY)
  message(STATUS "Seeded ${SRZGS_USER_DIR}/config.ini from src/platform/config/config.ini")
endif()

# The extracted disc srzgs_run and srzgs_preflight use for SRZGS_GAME_ID:
# SRZGS_GAME_ROOT when set; else game_assets if it holds that game (as the
# README's steps make it for Zero Gravity); else the copy the launcher
# extracted into the user directory. game_assets itself, the default before
# there were two games and so in the cache of older builds, means the same as
# unset: it is used only when it holds the game.
if(SRZGS_GAME_ROOT AND NOT SRZGS_GAME_ROOT STREQUAL "${CMAKE_SOURCE_DIR}/game_assets")
  set(_srzgs_game_root "${SRZGS_GAME_ROOT}")
else()
  set(_srzgs_game_root "${CMAKE_SOURCE_DIR}/game_assets")
  set(_srzgs_disc_id "")
  if(EXISTS "${_srzgs_game_root}/sys/boot.bin")
    file(READ "${_srzgs_game_root}/sys/boot.bin" _srzgs_disc_id LIMIT 6)
  endif()
  if(NOT _srzgs_disc_id STREQUAL SRZGS_GAME_ID)
    set(_srzgs_game_root "${SRZGS_USER_DIR}/games/${SRZGS_GAME_ID}")
  endif()
endif()
message(STATUS "srzgs_run starts ${SRZGS_GAME_ID} from ${_srzgs_game_root}")

# --- launch targets ----------------------------------------------------------
# A ';' inside a COMMAND argument is split into separate arguments by the
# generators, which silently dropped every extra run argument after the first.
# Encode the list with '|' here; RunGame.cmake decodes it.
string(REPLACE ";" "|" _srzgs_run_args_encoded "${SRZGS_RUN_ARGS}")
set(_srzgs_run_common
  -DGAME_ROOT=${_srzgs_game_root}
  -DUSER_DIR=${SRZGS_USER_DIR}
  -DCHASSIS_BUILD_DIR=${SRZGS_CHASSIS_BUILD_DIR}
  -DCHASSIS_SRC_DIR=${SRZGS_CHASSIS_DIR}
  "-DRUNNER=${SRZGS_RUNNER}"
  "-DEXTRA_ARGS=${_srzgs_run_args_encoded}")

add_custom_target(srzgs_run
  COMMAND ${CMAKE_COMMAND} -DMODE=game ${_srzgs_run_common}
          "-DMODULE=${SRZGS_STAGE_DIR}/$<TARGET_FILE_NAME:${SRZGS_MODULE_TARGET}>"
          -P "${CMAKE_CURRENT_SOURCE_DIR}/RunGame.cmake"
  DEPENDS srzgs_stage
  USES_TERMINAL
  VERBATIM)

add_custom_target(srzgs_run_baseline
  COMMAND ${CMAKE_COMMAND} -DMODE=baseline ${_srzgs_run_common}
          -P "${CMAKE_CURRENT_SOURCE_DIR}/RunGame.cmake"
  USES_TERMINAL
  VERBATIM)

if(UNIX)
  add_custom_target(srzgs_preflight
    COMMAND ${CMAKE_COMMAND} -E env "SRZGS_RUNNER=${SRZGS_RUNNER}"
            "SRZGS_GAME_ROOT=${_srzgs_game_root}" "SRZGS_GAME_ID=${SRZGS_GAME_ID}"
            bash "${CMAKE_SOURCE_DIR}/tools/preflight.sh"
            "${_srzgs_game_root}"
            "${SRZGS_STAGE_DIR}/$<TARGET_FILE_NAME:${SRZGS_MODULE_TARGET}>"
    DEPENDS srzgs_stage
    USES_TERMINAL
    VERBATIM)
  add_dependencies(srzgs_run srzgs_preflight)
endif()
