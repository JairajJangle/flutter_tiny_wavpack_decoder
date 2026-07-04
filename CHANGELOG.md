# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-07-04

### Added

- Decode WavPack (`.wv`) files to PCM `.wav` files on-device using the
  bundled, BSD-licensed WavPack 4.40 "tiny decoder" C library over
  `dart:ffi`, with no method channels and no platform-specific bridge code.
- Supported platforms: Android, iOS, macOS, Linux, Windows.
- `TinyWavpackDecoder.decode()` with `maxSamples`, `bitsPerSample`
  (8/16/24/32) and an `onProgress` callback delivering monotonically
  increasing values in `(0.0, 1.0]`.
- Decoding runs in a worker isolate; concurrent calls are automatically
  serialized (the native decoder is not reentrant).
- Typed failures via `WavpackDecodeException`; invalid arguments throw
  `ArgumentError` before any native code runs.
