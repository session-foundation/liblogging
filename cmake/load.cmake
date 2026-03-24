# cmake/load.cmake
#
# Include this script from a parent project to obtain the oxen::logging CMake target, which
# links against liblogging and publicly exposes fmt and spdlog (ensuring header availability for
# callers that use fmt formatters or spdlog types).
#
# Typical usage from a parent project that has liblogging as a submodule at
# `external/oxen-logging`:
#
#     include(external/oxen-logging/cmake/load.cmake)
#     target_link_libraries(myapp PRIVATE oxen::logging)
#
# This script attempts to find a suitable system-installed liblogging via pkg-config.  If found,
# it still runs the fmt/spdlog version check (and may fall back to the bundled submodules if the
# system fmt/spdlog are too old).  If no suitable system library is found the entire liblogging
# source tree is added as a subdirectory.
#
# Control variables (set before including this script):
#
#   OXEN_LOGGING_MIN_VERSION
#       Minimum acceptable version of the system oxen-logging library.  Defaults to 1.2.
#
#   OXEN_LOGGING_FORCE_SUBMODULES
#       Skip the system library search entirely; always build from the submodule.
#
#   BUILD_STATIC_DEPS
#       If true, implies OXEN_LOGGING_FORCE_SUBMODULES: all dependencies are loaded from
#       submodules and no system libraries are used.  This is the conventional variable used
#       by parent projects that need a fully self-contained static build.
#
#   OXEN_LOGGING_FMT_HEADER_ONLY
#       Use fmt in header-only mode (passed through to load_fmt_spdlog.cmake / the submodule).
#
#   OXEN_LOGGING_SPDLOG_HEADER_ONLY
#       Use spdlog in header-only mode (passed through to load_fmt_spdlog.cmake / the submodule).
#
# The liblogging source root is assumed to be the parent of the directory containing this file
# (i.e. the cmake/ directory within the liblogging tree).  If you have placed this file somewhere
# else you can override the detected root by setting OXEN_LOGGING_SOURCE_DIR before including.

if(TARGET oxen::logging)
    return()
endif()

# Resolve the liblogging source root: default to the parent of this cmake/ directory.
if(NOT DEFINED OXEN_LOGGING_SOURCE_DIR)
    get_filename_component(OXEN_LOGGING_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
endif()

if(NOT DEFINED OXEN_LOGGING_MIN_VERSION)
    set(OXEN_LOGGING_MIN_VERSION 1.2)
endif()

if(BUILD_STATIC_DEPS)
    set(OXEN_LOGGING_FORCE_SUBMODULES TRUE)
endif()

set(_oxen_logging_use_system FALSE)

if(NOT OXEN_LOGGING_FORCE_SUBMODULES)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(oxen_logging QUIET IMPORTED_TARGET
            liboxen-logging>=${OXEN_LOGGING_MIN_VERSION})
        if(oxen_logging_FOUND)
            message(STATUS "Found system oxen-logging ${oxen_logging_VERSION}")
            set(_oxen_logging_use_system TRUE)
        else()
            message(STATUS "System oxen-logging not found (or too old); using submodule")
        endif()
    else()
        message(STATUS "pkg-config not available; using oxen-logging submodule")
    endif()
endif()

if(_oxen_logging_use_system)
    # Even with the system library we need suitable fmt/spdlog targets, because liblogging's
    # public headers expose fmt types and because the system fmt/spdlog may be too old.
    # load_fmt_spdlog.cmake handles the version checks and submodule fallback for us.
    include("${OXEN_LOGGING_SOURCE_DIR}/cmake/load_fmt_spdlog.cmake")

    # Build an INTERFACE target that bundles the system liblogging with the resolved fmt/spdlog
    # targets, then alias it as oxen::logging so callers see a consistent target name.
    add_library(oxen-logging-system INTERFACE)
    target_link_libraries(oxen-logging-system INTERFACE
        PkgConfig::oxen_logging
        ${OXEN_LOGGING_FMT_TARGET}
        ${OXEN_LOGGING_SPDLOG_TARGET}
    )
    add_library(oxen::logging ALIAS oxen-logging-system)
else()
    # Add the full liblogging source tree as a subdirectory.  An explicit binary directory is
    # required because OXEN_LOGGING_SOURCE_DIR may be outside the current project's source tree.
    if(NOT DEFINED OXEN_LOGGING_BINARY_DIR)
        set(OXEN_LOGGING_BINARY_DIR oxen-logging)
    endif()
    add_subdirectory("${OXEN_LOGGING_SOURCE_DIR}" "${OXEN_LOGGING_BINARY_DIR}")
    # oxen::logging ALIAS is created by liblogging's own CMakeLists.txt.
endif()
