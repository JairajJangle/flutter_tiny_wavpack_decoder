import 'dart:typed_data';

/// Immutable description of one in-memory decode call.
///
/// Produced by [TinyWavpackDecoder.decodeBytes] after validation; consumed
/// by a [BytesDecodeRunner].
final class BytesDecodeRequest {
  /// Creates a request. All values are passed to the decoder as-is.
  const BytesDecodeRequest({
    required this.input,
    required this.maxSamples,
    required this.bitsPerSample,
  });

  /// The WavPack (`.wv`) bytes to decode.
  final Uint8List input;

  /// Maximum samples per channel to decode, or `-1` for the entire stream.
  final int maxSamples;

  /// Output bit depth: 8, 16, 24, or 32.
  final int bitsPerSample;
}

/// Outcome of one in-memory decode call.
final class BytesDecodeResult {
  /// Creates a successful result carrying the complete WAV file image.
  const BytesDecodeResult.success(Uint8List this.output) : error = '';

  /// Creates a failed result with the decoder's error message.
  const BytesDecodeResult.failure(this.error) : output = null;

  /// The complete WAV file bytes (44-byte header + PCM data), or null when
  /// the decode failed.
  final Uint8List? output;

  /// The decoder's error message when the decode failed, otherwise empty.
  final String error;

  /// Whether the decode succeeded.
  bool get success => output != null;
}

/// Executes a single in-memory decode.
///
/// The default implementation is platform-specific: the bundled C decoder
/// over `dart:ffi` in a worker isolate on native platforms, and the same C
/// code compiled to WASM running in a Web Worker on the web. Tests can
/// inject a fake via [TinyWavpackDecoder]'s constructor.
///
/// Implementations may invoke `onProgress` any number of times with values
/// in `[0, 1]`; [TinyWavpackDecoder] handles clamping, ordering, and the
/// terminal `1.0`.
abstract interface class BytesDecodeRunner {
  /// Runs one decode described by [request].
  Future<BytesDecodeResult> run(
    BytesDecodeRequest request,
    void Function(double progress) onProgress,
  );
}
