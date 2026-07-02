import 'native_decode_runner.dart';

/// [NativeDecodeRunner] backed by the bundled C decoder over `dart:ffi`.
final class FfiDecodeRunner implements NativeDecodeRunner {
  /// Creates the FFI-backed runner.
  const FfiDecodeRunner();

  @override
  Future<NativeDecodeResult> run(
    NativeDecodeRequest request,
    void Function(double progress) onProgress,
  ) {
    throw UnimplementedError();
  }
}
