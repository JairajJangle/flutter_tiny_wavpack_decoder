#!/usr/bin/env bash
# Builds the web decoder: compiles the in-memory entry point (ftwd_buffer.c)
# plus the vendored WavPack tiny decoder to web_assets/ftwd.{js,wasm} with
# Emscripten. The artifacts are committed so package consumers never need
# emcc; rerun this after changing anything under src/ that the web build
# uses, then commit the result.
#
# Requires emcc on PATH (https://emscripten.org, e.g. via emsdk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

emcc \
  "$ROOT/src/ftwd_buffer.c" \
  "$ROOT/src/tiny-wavpack/lib/bits.c" \
  "$ROOT/src/tiny-wavpack/lib/float.c" \
  "$ROOT/src/tiny-wavpack/lib/metadata.c" \
  "$ROOT/src/tiny-wavpack/lib/unpack.c" \
  "$ROOT/src/tiny-wavpack/lib/words.c" \
  "$ROOT/src/tiny-wavpack/lib/wputils.c" \
  -I "$ROOT/src" \
  -I "$ROOT/src/tiny-wavpack/lib" \
  -O2 \
  -sMODULARIZE=1 \
  -sEXPORT_NAME=createFtwdModule \
  -sENVIRONMENT=worker \
  -sALLOW_MEMORY_GROWTH=1 \
  -sALLOW_TABLE_GROWTH=1 \
  -sEXPORTED_FUNCTIONS=_ftwd_decode_buffer,_ftwd_free_buffer,_malloc,_free \
  -sEXPORTED_RUNTIME_METHODS=addFunction,removeFunction,getValue,UTF8ToString,HEAPU8 \
  -o "$ROOT/web_assets/ftwd.js"

echo "Built:"
ls -la "$ROOT/web_assets/ftwd.js" "$ROOT/web_assets/ftwd.wasm"
