/// Immutable description of one native decode call.
///
/// Produced by [TinyWavpackDecoder.decode] after validation; consumed by a
/// [NativeDecodeRunner].
final class NativeDecodeRequest {
  /// Creates a request. All values are passed to the native decoder as-is.
  const NativeDecodeRequest({
    required this.inputPath,
    required this.outputPath,
    required this.maxSamples,
    required this.bitsPerSample,
  });

  /// Path of the WavPack (`.wv`) file to read.
  final String inputPath;

  /// Path of the WAV file to write (overwritten if it exists).
  final String outputPath;

  /// Maximum samples per channel to decode, or `-1` for the entire file.
  final int maxSamples;

  /// Output bit depth: 8, 16, 24, or 32.
  final int bitsPerSample;
}

/// Outcome of one native decode call.
final class NativeDecodeResult {
  /// Creates a result. [error] is empty when [success] is true.
  const NativeDecodeResult({required this.success, required this.error});

  /// Whether the native decoder reported success.
  final bool success;

  /// The native decoder's error message when [success] is false.
  final String error;
}

/// Executes a single decode against the native layer.
///
/// The default implementation calls the bundled C decoder over `dart:ffi` in
/// a worker isolate. Tests (including consumers' widget tests) can inject a
/// fake via [TinyWavpackDecoder]'s constructor to avoid native code entirely.
///
/// Implementations may invoke `onProgress` any number of times with values
/// in `[0, 1]`; [TinyWavpackDecoder] handles clamping, ordering, and the
/// terminal `1.0`.
abstract interface class NativeDecodeRunner {
  /// Runs one decode described by [request].
  Future<NativeDecodeResult> run(
    NativeDecodeRequest request,
    void Function(double progress) onProgress,
  );
}
