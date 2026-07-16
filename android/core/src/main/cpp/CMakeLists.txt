cmake_minimum_required(VERSION 3.22.1)

project("core")

message("CMAKE_SOURCE_DIR ${CMAKE_SOURCE_DIR}")

message("CMAKE_BUILD_TYPE ${CMAKE_BUILD_TYPE}")


 if (NOT "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
     set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
     add_compile_options(-O3 -flto -g0 -fno-exceptions -fno-rtti)
     add_link_options(-flto -Wl,--gc-sections,--strip-all)
 endif ()

set(LIB_CLASH_PATH "${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libclash.so")
set(LIB_CLASH_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/../cpp/includes/${ANDROID_ABI}")
set(LIB_CLASH_HEADER_PATH "${LIB_CLASH_INCLUDE_DIR}/libclash.h")
set(BRIDE_HEADER_PATH "${LIB_CLASH_INCLUDE_DIR}/bride.h")

message("LIB_CLASH_PATH ${LIB_CLASH_PATH}")

# 方案 B：不再通过 DT_NEEDED 链接 libclash.so，
# 改为运行时 dlopen + dlsym 动态加载。这样 libclash.so 的文件名可以
# 带版本号（如 libclashn1928.so），且不受 Android linker namespace 限制。
add_library(${CMAKE_PROJECT_NAME} SHARED
        jni_helper.cpp
        core.cpp)
target_link_libraries(${CMAKE_PROJECT_NAME}
        dl      # dlopen/dlsym
        log     # __android_log_print
)
