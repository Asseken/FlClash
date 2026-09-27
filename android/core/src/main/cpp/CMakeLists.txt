cmake_minimum_required(VERSION 3.22.1)

project("core")

message("CMAKE_SOURCE_DIR ${CMAKE_SOURCE_DIR}")

message("CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE}")


if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    add_compile_options(-O3 -flto -g0 -fno-exceptions -fno-rtti)
    add_link_options(-flto -Wl,--gc-sections,--strip-all)
endif ()

set(LIB_CLASH_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/../cpp/includes/${ANDROID_ABI}")

# core.cpp no longer links the Core through DT_NEEDED: it dlopen()s the versioned
# libclash*.so the updater installs, so a downloaded Core can replace the bundled
# one without rebuilding this bridge. Because the link-time dependency is gone,
# the only thing still tying the build to the Core artifacts is the include
# below: keep it, so a build that ran before the hook produced the Core fails at
# compile time instead of shipping an APK without a Core. (AGP's configure
# fingerprint tracks only this file, so the check must not live in configure.)
include_directories(${LIB_CLASH_INCLUDE_DIR})
add_library(${CMAKE_PROJECT_NAME} SHARED
        jni_helper.cpp
        core.cpp)
target_link_libraries(${CMAKE_PROJECT_NAME}
        dl
        log)
