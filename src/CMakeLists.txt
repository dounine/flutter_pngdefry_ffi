# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(flutter_pngdefry_ffi_library VERSION 0.0.1 LANGUAGES C)

add_library(flutter_pngdefry_ffi SHARED
  "flutter_pngdefry_ffi.c"
)

set_target_properties(flutter_pngdefry_ffi PROPERTIES
  PUBLIC_HEADER flutter_pngdefry_ffi.h
  OUTPUT_NAME "flutter_pngdefry_ffi"
)

target_compile_definitions(flutter_pngdefry_ffi PUBLIC DART_SHARED_LIB)
