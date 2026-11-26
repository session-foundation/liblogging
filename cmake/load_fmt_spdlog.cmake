# This provides the fmt::fmt and spdlog::spdlog targets.  It is used internally by both
# CMakeLists.txt (when building liblogging) and cmake/load.cmake (when a parent project uses the
# system-installed liblogging).  Parent projects should include cmake/load.cmake rather than this
# file directly.

if(NOT OXEN_LOGGING_FORCE_SUBMODULES)
    if(NOT TARGET fmt::fmt)
        find_package(fmt 9.0.0 CONFIG QUIET)
        if(fmt_FOUND)
            message(STATUS "Found fmt ${fmt_VERSION}")
            # Make the target available to the parent project (which is the case if we go by
            # subproject, but isn't for packages we find via find_package).  cmake 3.24+ has a
            # `GLOBAL` flag in the find_package, but we need this to work on older cmakes as well.
            set_target_properties(fmt::fmt PROPERTIES IMPORTED_GLOBAL TRUE)
        else()
            message(STATUS "Did not find suitable fmt; using submodule")
        endif()
    endif()
    set(min_spdlog 1.9.1)
    if(NOT TARGET fmt::fmt OR fmt_VERSION VERSION_GREATER_EQUAL 10.0.0)
        set(min_spdlog 1.12.0)
    endif()

    if(NOT TARGET spdlog::spdlog)
        find_package(spdlog ${min_spdlog} CONFIG QUIET)
        if(spdlog_FOUND)
            message(STATUS "Found spdlog ${spdlog_VERSION}")
            # Make available in parent; see above.
            set_target_properties(spdlog::spdlog PROPERTIES IMPORTED_GLOBAL TRUE)
        else()
            message(STATUS "Did not find suitable spdlog; using submodule")
        endif()
    endif()
endif()

set(OXEN_LOGGING_FMT_TARGET fmt::fmt)
set(OXEN_LOGGING_SPDLOG_TARGET spdlog::spdlog)

if(NOT TARGET fmt::fmt)
    if(OXEN_LOGGING_FMT_HEADER_ONLY)
        set(OXEN_LOGGING_FMT_TARGET fmt::fmt-header-only)
    endif()
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/../fmt)

    # fmt 12.2.0 and 12.2.1 apply operator~ to their fallback 128-bit integer without defining it,
    # so they do not compile where the compiler has no native 128-bit integer and long double is
    # wider than 64 bits: of the targets we build for, 32-bit x86.  Upstream fixed it
    # (fmtlib/fmt#4813) but has not released the fix, so there this supplies the operator to the
    # code that needs it: fmt's own library source, or every consumer when fmt is header-only.
    #
    # Nothing else would say when this stops being wanted: it is only compiled for 32-bit x86, so
    # a fixed fmt would break that build alone, with a redefinition error.  Hence the version check.
    get_target_property(bundled_fmt_version fmt VERSION)
    if(bundled_fmt_version VERSION_GREATER 12.2.1)
        message(FATAL_ERROR
            "The bundled fmt is now ${bundled_fmt_version}.  If it defines operator~ for "
            "fmt::detail::uint128 (fmtlib/fmt#4813), remove this workaround and "
            "cmake/fmt-uint128-not.hpp; if it does not, raise the version in this check.")
    endif()

    include(CheckCXXSourceCompiles)
    check_cxx_source_compiles("
        #include <cfloat>
        #if defined(__SIZEOF_INT128__) || LDBL_MANT_DIG <= 53
        #error fmt compiles as it is
        #endif
        int main() {}"
        OXEN_LOGGING_FMT_LACKS_UINT128_NOT)
    if(OXEN_LOGGING_FMT_LACKS_UINT128_NOT)
        set(fmt_missing_operator
            "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-include \"${CMAKE_CURRENT_LIST_DIR}/fmt-uint128-not.hpp\">")
        target_compile_options(fmt PRIVATE "${fmt_missing_operator}")
        target_compile_options(fmt-header-only INTERFACE "${fmt_missing_operator}")
    endif()
endif()

if(NOT TARGET spdlog::spdlog)
    if(OXEN_LOGGING_FMT_HEADER_ONLY)
        set(SPDLOG_FMT_EXTERNAL_HO ON CACHE INTERNAL "")
    else()
        set(SPDLOG_FMT_EXTERNAL ON CACHE INTERNAL "")
    endif()
    if(OXEN_LOGGING_SPDLOG_HEADER_ONLY)
        set(OXEN_LOGGING_SPDLOG_TARGET spdlog::spdlog_header_only)
    endif()
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/../spdlog)
endif()
