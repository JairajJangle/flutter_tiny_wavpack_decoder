// Web platform defaults. Selected by the conditional import in
// decoder.dart; keep the top-level API identical to
// platform_defaults_io.dart and platform_defaults_stub.dart.
import 'bytes_decode_runner.dart';
import 'native_decode_runner.dart';
import 'wasm_decode_runner.dart';

/// Whether path-based [TinyWavpackDecoder.decode] works on this platform.
const bool pathDecodingSupported = false;

/// Path-based decoding needs a real filesystem, which browsers don't have.
NativeDecodeRunner defaultPathRunner() => throw UnsupportedError(
  'TinyWavpackDecoder.decode() is not supported on the web because there '
  'is no filesystem; use decodeBytes() instead.',
);

/// The default bytes runner: the C decoder compiled to WASM in a Web Worker.
BytesDecodeRunner defaultBytesRunner() => WasmDecodeRunner.instance;

/// Only reachable with an injected test runner on the web; the real
/// pre-flight check is native-only.
bool inputFileExists(String path) => true;
