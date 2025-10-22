include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(limit_engine_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(limit_engine_setup_options)
  option(limit_engine_ENABLE_HARDENING "Enable hardening" ON)
  option(limit_engine_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    limit_engine_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    limit_engine_ENABLE_HARDENING
    OFF)

  limit_engine_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR limit_engine_PACKAGING_MAINTAINER_MODE)
    option(limit_engine_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(limit_engine_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(limit_engine_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(limit_engine_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(limit_engine_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(limit_engine_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(limit_engine_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(limit_engine_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(limit_engine_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(limit_engine_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(limit_engine_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(limit_engine_ENABLE_PCH "Enable precompiled headers" OFF)
    option(limit_engine_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(limit_engine_ENABLE_IPO "Enable IPO/LTO" ON)
    option(limit_engine_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(limit_engine_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(limit_engine_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(limit_engine_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(limit_engine_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(limit_engine_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(limit_engine_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(limit_engine_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(limit_engine_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(limit_engine_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(limit_engine_ENABLE_PCH "Enable precompiled headers" OFF)
    option(limit_engine_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      limit_engine_ENABLE_IPO
      limit_engine_WARNINGS_AS_ERRORS
      limit_engine_ENABLE_USER_LINKER
      limit_engine_ENABLE_SANITIZER_ADDRESS
      limit_engine_ENABLE_SANITIZER_LEAK
      limit_engine_ENABLE_SANITIZER_UNDEFINED
      limit_engine_ENABLE_SANITIZER_THREAD
      limit_engine_ENABLE_SANITIZER_MEMORY
      limit_engine_ENABLE_UNITY_BUILD
      limit_engine_ENABLE_CLANG_TIDY
      limit_engine_ENABLE_CPPCHECK
      limit_engine_ENABLE_COVERAGE
      limit_engine_ENABLE_PCH
      limit_engine_ENABLE_CACHE)
  endif()

  limit_engine_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (limit_engine_ENABLE_SANITIZER_ADDRESS OR limit_engine_ENABLE_SANITIZER_THREAD OR limit_engine_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(limit_engine_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(limit_engine_global_options)
  if(limit_engine_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    limit_engine_enable_ipo()
  endif()

  limit_engine_supports_sanitizers()

  if(limit_engine_ENABLE_HARDENING AND limit_engine_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR limit_engine_ENABLE_SANITIZER_UNDEFINED
       OR limit_engine_ENABLE_SANITIZER_ADDRESS
       OR limit_engine_ENABLE_SANITIZER_THREAD
       OR limit_engine_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${limit_engine_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${limit_engine_ENABLE_SANITIZER_UNDEFINED}")
    limit_engine_enable_hardening(limit_engine_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(limit_engine_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(limit_engine_warnings INTERFACE)
  add_library(limit_engine_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  limit_engine_set_project_warnings(
    limit_engine_warnings
    ${limit_engine_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(limit_engine_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    limit_engine_configure_linker(limit_engine_options)
  endif()

  include(cmake/Sanitizers.cmake)
  limit_engine_enable_sanitizers(
    limit_engine_options
    ${limit_engine_ENABLE_SANITIZER_ADDRESS}
    ${limit_engine_ENABLE_SANITIZER_LEAK}
    ${limit_engine_ENABLE_SANITIZER_UNDEFINED}
    ${limit_engine_ENABLE_SANITIZER_THREAD}
    ${limit_engine_ENABLE_SANITIZER_MEMORY})

  set_target_properties(limit_engine_options PROPERTIES UNITY_BUILD ${limit_engine_ENABLE_UNITY_BUILD})

  if(limit_engine_ENABLE_PCH)
    target_precompile_headers(
      limit_engine_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(limit_engine_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    limit_engine_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(limit_engine_ENABLE_CLANG_TIDY)
    limit_engine_enable_clang_tidy(limit_engine_options ${limit_engine_WARNINGS_AS_ERRORS})
  endif()

  if(limit_engine_ENABLE_CPPCHECK)
    limit_engine_enable_cppcheck(${limit_engine_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(limit_engine_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    limit_engine_enable_coverage(limit_engine_options)
  endif()

  if(limit_engine_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(limit_engine_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(limit_engine_ENABLE_HARDENING AND NOT limit_engine_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR limit_engine_ENABLE_SANITIZER_UNDEFINED
       OR limit_engine_ENABLE_SANITIZER_ADDRESS
       OR limit_engine_ENABLE_SANITIZER_THREAD
       OR limit_engine_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    limit_engine_enable_hardening(limit_engine_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
