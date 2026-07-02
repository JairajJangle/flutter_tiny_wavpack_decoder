/// Decode WavPack (`.wv`) audio files to PCM `.wav` files on-device, using
/// the bundled WavPack 4.40 "tiny decoder" C library over `dart:ffi`.
library;

export 'src/decoder.dart' show TinyWavpackDecoder;
export 'src/exceptions.dart' show WavpackDecodeException;
export 'src/native_decode_runner.dart'
    show NativeDecodeRequest, NativeDecodeResult, NativeDecodeRunner;
