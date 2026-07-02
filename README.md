# flutter_tiny_wavpack_decoder

[![pub package](https://img.shields.io/pub/v/flutter_tiny_wavpack_decoder.svg)](https://pub.dev/packages/flutter_tiny_wavpack_decoder)
[![CI](https://github.com/JairajJangle/flutter_tiny_wavpack_decoder/actions/workflows/ci.yml/badge.svg)](https://github.com/JairajJangle/flutter_tiny_wavpack_decoder/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Decode WavPack (`.wv`) audio files to PCM `.wav` files on-device, powered by
the tiny, dependency-free [WavPack](https://www.wavpack.com) 4.40
"tiny decoder" C library over `dart:ffi`.

This is the Flutter counterpart of
[react-native-tiny-wavpack-decoder](https://github.com/JairajJangle/react-native-tiny-wavpack-decoder),
sharing the exact same (unmodified) C decoder.

## Features

- 🎵 `.wv` → `.wav` (PCM, canonical 44-byte header) fully on-device
- 📊 Live decode progress callback (`0.0 → 1.0`)
- 🎚 Output bit depth selection: 8, 16, 24, or 32 bits per sample
- ✂️ Optional `maxSamples` cap for partial decodes
- 🧵 Decodes in a worker isolate — the UI never blocks
- 🪶 Pure `dart:ffi` — no method channels, no platform bridge code
- 🔒 Concurrent calls are safe: decodes are automatically serialized

## Platform support

| Android | iOS | macOS | Linux | Windows |
|:-------:|:---:|:-----:|:-----:|:-------:|
|    ✅    |  ✅  |   ✅   |   ✅   |    ✅    |

## Install

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
  print('Done!');
} on WavpackDecodeException catch (e) {
  print('Decode failed: ${e.message}');
}
```

See [`example/`](example/) for a complete app with a progress bar.

## API

### `TinyWavpackDecoder.decode(...)`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `inputPath` | `String` | required | Path of the `.wv` file to decode. |
| `outputPath` | `String` | required | Path of the `.wav` file to write (overwritten if present). |
| `maxSamples` | `int` | `-1` | Max samples per channel to decode; `-1` = entire file. |
| `bitsPerSample` | `int` | `16` | Output bit depth: 8, 16, 24, or 32. |
| `onProgress` | `void Function(double)?` | `null` | Progress callback on the caller's isolate. |

Returns `Future<void>` that completes when the WAV file is fully written.

**Errors:** invalid `bitsPerSample`/`maxSamples` throw `ArgumentError`
immediately; runtime failures (missing input, invalid/corrupt WavPack data,
CRC errors, unwritable output) throw `WavpackDecodeException` with the native
decoder's message.

**Progress guarantees:** values are strictly increasing within `(0.0, 1.0]`,
a terminal `1.0` is always delivered on success, and no callback fires after
the returned future completes. Granularity is one callback per 4096 decoded
frames.

**Concurrency:** the bundled C decoder keeps static state and is not
reentrant, so all decodes in the process run through one queue — concurrent
`decode()` calls are safe but execute one at a time.

### Testing your own code

`TinyWavpackDecoder`'s constructor accepts a custom `NativeDecodeRunner`, so
you can fake the native layer in widget/unit tests without any native
library:

```dart
class FakeRunner implements NativeDecodeRunner {
  @override
  Future<NativeDecodeResult> run(NativeDecodeRequest request,
      void Function(double) onProgress) async {
    onProgress(1.0);
    return const NativeDecodeResult(success: true, error: '');
  }
}

final decoder = TinyWavpackDecoder(runner: FakeRunner());
```

## Limitations

Inherited from the WavPack 4.40 tiny decoder (see
`src/tiny-wavpack/lib/readme.txt`):

- Only the **first two channels** of multichannel files are decoded.
- **No correction (`.wvc`) file support** — pure lossy/lossless `.wv` only.
- WavPack stream versions **4.2 – 4.10** only (no pre-4.0 files).
- Floating-point audio is returned **clipped to 24-bit** integer data.
- Output WAV is limited to < 4 GiB (32-bit RIFF sizes).

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

The C sources under `src/tiny-wavpack/` are vendored **byte-identical** from
the original project and are never modified; see
`src/tiny-wavpack/UPSTREAM.md`.

## Credits

- [WavPack](https://www.wavpack.com) and its tiny decoder are by David
  Bryant (Copyright © 1998–2006 Conifer Software, BSD license — see
  [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)).
- Original React Native plugin:
  [react-native-tiny-wavpack-decoder](https://github.com/JairajJangle/react-native-tiny-wavpack-decoder).

## License

[MIT](LICENSE) © Jairaj Jangle. Bundled WavPack tiny decoder is BSD-licensed
(see [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)).

## 🙏 Support the project

[![LiberaPay](https://img.shields.io/badge/LiberaPay-FutureJJ-yellow?logo=liberapay)](https://liberapay.com/FutureJJ/donate)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-futurejj-ff5f5f?logo=ko-fi)](https://ko-fi.com/futurejj)
[![PayPal](https://img.shields.io/badge/PayPal-jairajjangle001-00457C?logo=paypal)](https://www.paypal.com/paypalme/jairajjangle001/usd)
[![UPI](https://img.shields.io/badge/UPI-QR%20code-orange)](https://github.com/JairajJangle/OpenCV-Catalogue/blob/master/.github/Jairaj_Jangle_Google_Pay_UPI_QR_Code.jpg)
