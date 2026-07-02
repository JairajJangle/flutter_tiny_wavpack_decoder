# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(flutter_tiny_wavpack_decoder_library VERSION 1.0.0 LANGUAGES C)

add_library(flutter_tiny_wavpack_decoder SHARED
  "ftwd_shim.c"
  "tiny-wavpack/common/TinyWavPackDecoderInterface.c"
  "tiny-wavpack/lib/bits.c"
  "tiny-wavpack/lib/float.c"
  "tiny-wavpack/lib/metadata.c"
  "tiny-wavpack/lib/unpack.c"
  "tiny-wavpack/lib/words.c"
  "tiny-wavpack/lib/wputils.c"
)

set_target_properties(flutter_tiny_wavpack_decoder PROPERTIES
  PUBLIC_HEADER ftwd_shim.h
  OUTPUT_NAME "flutter_tiny_wavpack_decoder"
  C_STANDARD 11
  C_STANDARD_REQUIRED ON
)

# TinyWavPackDecoderInterface.c includes "wavpack.h" from the vendored lib/.
target_include_directories(flutter_tiny_wavpack_decoder PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/tiny-wavpack/lib"
)

target_compile_definitions(flutter_tiny_wavpack_decoder PUBLIC DART_SHARED_LIB)

if (MSVC)
  # The vendored sources use fopen/strncpy; silence C4996 without editing them.
  target_compile_definitions(flutter_tiny_wavpack_decoder PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(flutter_tiny_wavpack_decoder PRIVATE "-Wl,-z,max-page-size=16384")
endif()
