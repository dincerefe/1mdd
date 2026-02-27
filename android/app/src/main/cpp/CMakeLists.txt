cmake_minimum_required(VERSION 3.10)

project(native_config)

# Add native library
add_library(native_config SHARED
    native_config.cpp
)

# Link libraries
find_library(log-lib log)
target_link_libraries(native_config ${log-lib})
