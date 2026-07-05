/// Decode WavPack (`.wv`) audio to PCM `.wav` on-device, using the bundled
/// WavPack 4.40 "tiny decoder" C library — over `dart:ffi` on native
/// platforms, and as WASM inside a Web Worker on the web.
library;

export 'src/bytes_decode_runner.dart'
    show BytesDecodeRequest, BytesDecodeResult, BytesDecodeRunner;
export 'src/decoder.dart' show TinyWavpackDecoder;
export 'src/exceptions.dart' show WavpackDecodeException;
export 'src/native_decode_runner.dart'
    show NativeDecodeRequest, NativeDecodeResult, NativeDecodeRunner;
