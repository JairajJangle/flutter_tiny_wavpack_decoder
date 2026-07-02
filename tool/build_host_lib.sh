#!/usr/bin/env bash
# Builds the native decoder as a host shared library into build/host/ so the
# FFI integration tests in test/ffi/ can exercise the real C code under
# `flutter test` (no device needed). CI runs this before testing; locally run
# it once (and again after changing anything under src/).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cmake -S "$ROOT/src" -B "$ROOT/build/host" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ROOT/build/host" --config Release
