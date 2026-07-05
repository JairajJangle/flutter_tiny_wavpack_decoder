// Fallback for platforms with neither dart:ffi nor dart:js_interop. Never
// used by Flutter's supported targets; exists so the conditional import in
// decoder.dart always resolves. Keep the top-level API identical to
// platform_defaults_io.dart and platform_defaults_web.dart.
import 'bytes_decode_runner.dart';
import 'native_decode_runner.dart';

/// Whether path-based [TinyWavpackDecoder.decode] works on this platform.
const bool pathDecodingSupported = false;

/// No decoder implementation exists for this platform.
NativeDecodeRunner defaultPathRunner() =>
    throw UnsupportedError('flutter_tiny_wavpack_decoder: unsupported platform');

/// No decoder implementation exists for this platform.
BytesDecodeRunner defaultBytesRunner() =>
    throw UnsupportedError('flutter_tiny_wavpack_decoder: unsupported platform');

/// Only reachable with an injected test runner.
bool inputFileExists(String path) => true;
