cmake_minimum_required(VERSION 3.22)
project(mirror_dna_cv LANGUAGES C CXX)

if(ANDROID OR IOS)
  # Build only the two required OpenCV modules for the target ABI.
  include(FetchContent)
  set(BUILD_LIST core,imgproc CACHE STRING "" FORCE)
  foreach(flag BUILD_SHARED_LIBS BUILD_TESTS BUILD_PERF_TESTS BUILD_EXAMPLES
          BUILD_opencv_apps BUILD_JAVA BUILD_ANDROID_PROJECTS WITH_IPP WITH_ITT
          WITH_OPENCL WITH_ADE WITH_LAPACK WITH_EIGEN WITH_CAROTENE)
    set(${flag} OFF CACHE BOOL "" FORCE)
  endforeach()
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)
  FetchContent_Declare(opencv
    GIT_REPOSITORY https://github.com/opencv/opencv.git
    GIT_TAG 4.10.0 GIT_SHALLOW TRUE)
  FetchContent_MakeAvailable(opencv)
else()
  find_path(OPENCV_INCLUDE opencv2/core.hpp PATH_SUFFIXES opencv4 REQUIRED)
  find_library(CV_CORE opencv_core REQUIRED)
  find_library(CV_IMGPROC opencv_imgproc REQUIRED)
endif()

add_library(cv_engine SHARED src/cv_engine.cpp)
target_include_directories(cv_engine PUBLIC include)
target_compile_features(cv_engine PRIVATE cxx_std_17)
if(ANDROID OR IOS)
  target_link_libraries(cv_engine PRIVATE opencv_core opencv_imgproc)
else()
  target_include_directories(cv_engine PRIVATE ${OPENCV_INCLUDE})
  target_link_libraries(cv_engine PRIVATE ${CV_CORE} ${CV_IMGPROC})
endif()
if(IOS)
  set_target_properties(cv_engine PROPERTIES FRAMEWORK TRUE
    MACOSX_FRAMEWORK_IDENTIFIER app.mirrordna.cv-engine
    INSTALL_NAME_DIR "@rpath" BUILD_WITH_INSTALL_NAME_DIR TRUE)
  install(TARGETS cv_engine FRAMEWORK DESTINATION Frameworks COMPONENT mirror_dna)
endif()

if(NOT CMAKE_CROSSCOMPILING)
  include(CTest)
  if(BUILD_TESTING)
    find_package(GTest REQUIRED)
    add_executable(cv_engine_tests tests/abi_test.cpp)
    target_link_libraries(cv_engine_tests PRIVATE cv_engine GTest::gtest_main)
    include(GoogleTest)
    gtest_discover_tests(cv_engine_tests)
  endif()
endif()
