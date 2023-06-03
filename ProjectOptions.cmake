include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(tinyDL_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(tinyDL_setup_options)
  option(tinyDL_ENABLE_HARDENING "Enable hardening" ON)
  option(tinyDL_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    tinyDL_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    tinyDL_ENABLE_HARDENING
    OFF)

  tinyDL_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR tinyDL_PACKAGING_MAINTAINER_MODE)
    option(tinyDL_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(tinyDL_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(tinyDL_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(tinyDL_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(tinyDL_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(tinyDL_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(tinyDL_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(tinyDL_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(tinyDL_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(tinyDL_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(tinyDL_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(tinyDL_ENABLE_PCH "Enable precompiled headers" OFF)
    option(tinyDL_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(tinyDL_ENABLE_IPO "Enable IPO/LTO" ON)
    option(tinyDL_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(tinyDL_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(tinyDL_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(tinyDL_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(tinyDL_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(tinyDL_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(tinyDL_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(tinyDL_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(tinyDL_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(tinyDL_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(tinyDL_ENABLE_PCH "Enable precompiled headers" OFF)
    option(tinyDL_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      tinyDL_ENABLE_IPO
      tinyDL_WARNINGS_AS_ERRORS
      tinyDL_ENABLE_USER_LINKER
      tinyDL_ENABLE_SANITIZER_ADDRESS
      tinyDL_ENABLE_SANITIZER_LEAK
      tinyDL_ENABLE_SANITIZER_UNDEFINED
      tinyDL_ENABLE_SANITIZER_THREAD
      tinyDL_ENABLE_SANITIZER_MEMORY
      tinyDL_ENABLE_UNITY_BUILD
      tinyDL_ENABLE_CLANG_TIDY
      tinyDL_ENABLE_CPPCHECK
      tinyDL_ENABLE_COVERAGE
      tinyDL_ENABLE_PCH
      tinyDL_ENABLE_CACHE)
  endif()

  tinyDL_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (tinyDL_ENABLE_SANITIZER_ADDRESS OR tinyDL_ENABLE_SANITIZER_THREAD OR tinyDL_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(tinyDL_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(tinyDL_global_options)
  if(tinyDL_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    tinyDL_enable_ipo()
  endif()

  tinyDL_supports_sanitizers()

  if(tinyDL_ENABLE_HARDENING AND tinyDL_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR tinyDL_ENABLE_SANITIZER_UNDEFINED
       OR tinyDL_ENABLE_SANITIZER_ADDRESS
       OR tinyDL_ENABLE_SANITIZER_THREAD
       OR tinyDL_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${tinyDL_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${tinyDL_ENABLE_SANITIZER_UNDEFINED}")
    tinyDL_enable_hardening(tinyDL_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(tinyDL_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(tinyDL_warnings INTERFACE)
  add_library(tinyDL_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  tinyDL_set_project_warnings(
    tinyDL_warnings
    ${tinyDL_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(tinyDL_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(tinyDL_options)
  endif()

  include(cmake/Sanitizers.cmake)
  tinyDL_enable_sanitizers(
    tinyDL_options
    ${tinyDL_ENABLE_SANITIZER_ADDRESS}
    ${tinyDL_ENABLE_SANITIZER_LEAK}
    ${tinyDL_ENABLE_SANITIZER_UNDEFINED}
    ${tinyDL_ENABLE_SANITIZER_THREAD}
    ${tinyDL_ENABLE_SANITIZER_MEMORY})

  set_target_properties(tinyDL_options PROPERTIES UNITY_BUILD ${tinyDL_ENABLE_UNITY_BUILD})

  if(tinyDL_ENABLE_PCH)
    target_precompile_headers(
      tinyDL_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(tinyDL_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    tinyDL_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(tinyDL_ENABLE_CLANG_TIDY)
    tinyDL_enable_clang_tidy(tinyDL_options ${tinyDL_WARNINGS_AS_ERRORS})
  endif()

  if(tinyDL_ENABLE_CPPCHECK)
    tinyDL_enable_cppcheck(${tinyDL_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(tinyDL_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    tinyDL_enable_coverage(tinyDL_options)
  endif()

  if(tinyDL_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(tinyDL_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(tinyDL_ENABLE_HARDENING AND NOT tinyDL_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR tinyDL_ENABLE_SANITIZER_UNDEFINED
       OR tinyDL_ENABLE_SANITIZER_ADDRESS
       OR tinyDL_ENABLE_SANITIZER_THREAD
       OR tinyDL_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    tinyDL_enable_hardening(tinyDL_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
