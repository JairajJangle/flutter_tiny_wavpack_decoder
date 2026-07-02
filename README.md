# flutter_tiny_wavpack_decoder

[![pub package](https://img.shields.io/pub/v/flutter_tiny_wavpack_decoder.svg)](https://pub.dev/packages/flutter_tiny_wavpack_decoder)
[![CI](https://github.com/JairajJangle/flutter_tiny_wavpack_decoder/actions/workflows/ci.yml/badge.svg)](https://github.com/JairajJangle/flutter_tiny_wavpack_decoder/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/JairajJangle/flutter_tiny_wavpack_decoder/blob/main/LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub-ea4aaa?logo=github-sponsors)](https://github.com/sponsors/JairajJangle)

A Flutter plugin that decodes WavPack (`.wv`) audio files to PCM `.wav` files
on-device, powered by the tiny, dependency-free
[WavPack](https://www.wavpack.com) 4.40 "tiny decoder" C library called
directly through `dart:ffi`.

It is the Flutter counterpart of
[react-native-tiny-wavpack-decoder](https://github.com/JairajJangle/react-native-tiny-wavpack-decoder)
and shares the exact same, unmodified C decoder.

## Features

- Decode `.wv` to `.wav` (PCM, canonical 44-byte header) fully on-device.
- Live decode progress callback reporting values from 0.0 to 1.0.
- Output bit depth selection: 8, 16, 24, or 32 bits per sample.
- Optional `maxSamples` cap for partial decodes.
- Decoding runs in a worker isolate, so the UI thread never blocks.
- Pure `dart:ffi`: no method channels and no platform bridge code.
- Concurrent calls are safe; decodes are automatically serialized.

## Platform support

| Android | iOS | macOS | Linux | Windows |
|:-------:|:---:|:-----:|:-----:|:-------:|
|   Yes   | Yes |  Yes  |  Yes  |   Yes   |

## Requirements

- Flutter 3.27.0 or newer.
- Dart SDK 3.9.0 or newer.

## Installation

```sh
flutter pub add flutter_tiny_wavpack_decoder
```

## Usage

```dart
import 'package:flutter_tiny_wavpack_decoder/flutter_tiny_wavpack_decoder.dart';

final decoder = TinyWavpackDecoder();

try {
  await decoder.decode(
    inputPath: '/path/to/audio.wv',
    outputPath: '/path/to/audio.wav',
    // Optional:
    bitsPerSample: 16, // 8, 16 (default), 24, or 32
    maxSamples: -1,    // -1 (default) decodes the whole file
    onProgress: (progress) {
      print('Decoding: ${(progress * 100).toStringAsFixed(0)}%');
    },
  );
  print('Done');
} on WavpackDecodeException catch (e) {
  print('Decode failed: ${e.message}');
}
```

See the [`example/`](example/) app for a complete UI with a progress bar.

### Testing your own code

The `TinyWavpackDecoder` constructor accepts a custom `NativeDecodeRunner`, so
you can fake the native layer in widget and unit tests without loading any
native library:

```dart
class FakeRunner implements NativeDecodeRunner {
  @override
  Future<NativeDecodeResult> run(
    NativeDecodeRequest request,
    void Function(double) onProgress,
  ) async {
    onProgress(1.0);
    return const NativeDecodeResult(success: true, error: '');
  }
}

final decoder = TinyWavpackDecoder(runner: FakeRunner());
```

## API

### `TinyWavpackDecoder.decode(...)`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `inputPath` | `String` | required | Path of the `.wv` file to decode. |
| `outputPath` | `String` | required | Path of the `.wav` file to write (overwritten if present). |
| `maxSamples` | `int` | `-1` | Max samples per channel to decode; `-1` decodes the entire file. |
| `bitsPerSample` | `int` | `16` | Output bit depth: 8, 16, 24, or 32. |
| `onProgress` | `void Function(double)?` | `null` | Progress callback on the caller's isolate. |

Returns a `Future<void>` that completes once the WAV file is fully written.

Invalid `bitsPerSample` or `maxSamples` throw `ArgumentError` immediately.
Runtime failures (missing input, invalid or corrupt WavPack data, CRC errors,
unwritable output) throw `WavpackDecodeException` carrying the native decoder's
message.

Progress values are strictly increasing within the range 0.0 to 1.0, a final
1.0 is always delivered on success, and no callback fires after the returned
future completes. Granularity is one callback per 4096 decoded frames.

Because the bundled C decoder keeps static state and is not reentrant, all
decodes in the process run through one queue. Concurrent `decode()` calls are
safe but execute one at a time.

## Limitations

Inherited from the WavPack 4.40 tiny decoder (see
`src/tiny-wavpack/lib/readme.txt`):

- Only the first two channels of multichannel files are decoded.
- No correction (`.wvc`) file support; plain lossy or lossless `.wv` only.
- WavPack stream versions 4.2 to 4.10 only (no pre-4.0 files).
- Floating-point audio is returned clipped to 24-bit integer data.
- Output WAV is limited to less than 4 GiB (32-bit RIFF sizes).

## Development

```sh
# Run the pure-Dart unit tests (no native build needed):
flutter test test/unit

# Build the native library for the host, then run the full suite including
# the real-C integration tests (golden byte-exact round-trip, error paths):
tool/build_host_lib.sh
flutter test

# Run the example on desktop:
cd example && flutter run -d macos   # or -d linux / -d windows
```

The C sources under `src/tiny-wavpack/` are vendored byte-identical from the
original project and are never modified; see `src/tiny-wavpack/UPSTREAM.md`.

## Credits

- [WavPack](https://www.wavpack.com) and its tiny decoder are by David Bryant
  (Copyright (c) 1998-2006 Conifer Software, BSD license; see
  [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)).
- Original React Native plugin:
  [react-native-tiny-wavpack-decoder](https://github.com/JairajJangle/react-native-tiny-wavpack-decoder).

## License

[MIT](LICENSE) (c) Jairaj Jangle. The bundled WavPack tiny decoder is
BSD-licensed (see [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)).

## Support the project

<p align="center" valign="center">
  <a href="https://www.paypal.com/paypalme/jairajjangle001/usd">
    <img src=".github/assets/paypal_donate.png" alt="Paypal_Donation_Button" height="50" >
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://github.com/sponsors/JairajJangle">
    <img src=".github/assets/github_sponsor.svg" alt="GitHub_Sponsor_Button" height="50" >
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://liberapay.com/FutureJJ/donate">
    <img src=".github/assets/liberapay_donate.svg" alt="Liberapay_Donation_Button" height="50" >
  </a>
</p>
