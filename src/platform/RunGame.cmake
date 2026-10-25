# =============================================================================
# RunGame.cmake - launch the ModernGekko runner on our module (script mode).
#
#   cmake -DMODE=game|baseline -DGAME_ROOT=<dir> -DUSER_DIR=<dir>
#         -DCHASSIS_BUILD_DIR=<dir> -DCHASSIS_SRC_DIR=<dir>
#         [-DMODULE=<file>] [-DRUNNER=<file>] [-DEXTRA_ARGS="a;b"] -P RunGame.cmake
#
# Why a script and not a plain COMMAND: the runner is located when the target
# RUNS, not at configure time, so building the chassis after configuring the
# game does not leave a stale "runner not found".
#
#   MODE=game      our module, no interpreter fallback: a rejected module is a
#                  loud error ("native module was rejected: ...").
#   MODE=baseline  no module, Dolphin's CPU core only. Proves the chassis, the
#                  disc and the graphics work independently of our recompile.
# =============================================================================
cmake_minimum_required(VERSION 3.22)

foreach(_var MODE GAME_ROOT USER_DIR CHASSIS_BUILD_DIR CHASSIS_SRC_DIR)
  if(NOT DEFINED ${_var} OR "${${_var}}" STREQUAL "")
    message(FATAL_ERROR "RunGame.cmake: -D${_var}=... is required")
  endif()
endforeach()
if(NOT MODE STREQUAL "game" AND NOT MODE STREQUAL "baseline")
  message(FATAL_ERROR "RunGame.cmake: MODE must be 'game' or 'baseline' (got '${MODE}')")
endif()

# --- runner ------------------------------------------------------------------
if(RUNNER)
  set(_runner "${RUNNER}")
else()
  # Dolphin's CMake picks the output directory: <build>/Binaries on Linux,
  # <source>/Binary/x64 on Windows.
  find_program(_runner NAMES moderngekko-run
    HINTS "${CHASSIS_BUILD_DIR}/Binaries" "${CHASSIS_SRC_DIR}/Binary/x64"
    PATH_SUFFIXES Release Debug
    NO_DEFAULT_PATH)
endif()
if(NOT _runner OR NOT EXISTS "${_runner}")
  message(FATAL_ERROR
    "moderngekko-run not found under ${CHASSIS_BUILD_DIR}/Binaries.\n"
    "Build it with: tools/build_tools.sh --chassis   (or pass -DSRZGS_RUNNER=<path>)")
endif()
get_filename_component(_runner_dir "${_runner}" DIRECTORY)
if(NOT IS_DIRECTORY "${_runner_dir}/Sys")
  message(FATAL_ERROR
    "${_runner_dir}/Sys is missing. The runner needs its Sys/ data next to it; "
    "rebuild with tools/build_tools.sh --chassis instead of copying the binary.")
endif()

# --- arguments ---------------------------------------------------------------
# --no-mods: the mod loader is a later phase; keep Phase 1 runs deterministic.
set(_args --game "${GAME_ROOT}" --user-dir "${USER_DIR}" --no-mods)
if(MODE STREQUAL "baseline")
  list(APPEND _args --allow-interpreter)
else()
  if(NOT MODULE OR NOT EXISTS "${MODULE}")
    message(FATAL_ERROR "Module not found: '${MODULE}'. Build it: cmake --build <dir>")
  endif()
  list(APPEND _args --module "${MODULE}")
endif()
if(EXTRA_ARGS)
  string(REPLACE "|" ";" EXTRA_ARGS "${EXTRA_ARGS}")   # decode (see CMakeLists.txt)
  list(APPEND _args ${EXTRA_ARGS})
endif()

message(STATUS "mode:   ${MODE}")
message(STATUS "runner: ${_runner}")
message(STATUS "args:   ${_args}")

# STATICRECOMP_MODULE would make the runner pick a module behind our back.
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E env --unset=STATICRECOMP_MODULE "${_runner}" ${_args}
  RESULT_VARIABLE _rc)
if(NOT _rc STREQUAL "0")
  message(FATAL_ERROR "moderngekko-run ended with: ${_rc}")
endif()
