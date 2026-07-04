## [1.0.1](https://github.com/JairajJangle/flutter_tiny_wavpack_decoder/compare/v1.0.0...v1.0.1) (2026-07-04)


### Bug Fixes

* verify automated release pipeline ([f34cb9d](https://github.com/JairajJangle/flutter_tiny_wavpack_decoder/commit/f34cb9db7b6d6e5adb66284a86a699a2f6af098f))

# Changelog

## 1.0.0

Initial release. Flutter port of
[react-native-tiny-wavpack-decoder](https://github.com/JairajJangle/react-native-tiny-wavpack-decoder).

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
