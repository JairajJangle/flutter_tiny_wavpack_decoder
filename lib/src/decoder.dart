import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

import 'exceptions.dart';
import 'ffi_decode_runner.dart';
import 'native_decode_runner.dart';

/// Decodes WavPack (`.wv`) files to PCM `.wav` files using the bundled
/// WavPack 4.40 "tiny decoder" C library via `dart:ffi`.
///
/// The decode itself runs in a worker isolate, so the calling (UI) isolate is
/// never blocked. The native decoder is **not reentrant**: all decodes in the
/// process are automatically serialized through one internal queue shared by
/// every [TinyWavpackDecoder] instance, so concurrent calls are safe but run
/// one at a time.
///
/// ```dart
/// final decoder = TinyWavpackDecoder();
/// await decoder.decode(
///   inputPath: '/path/to/audio.wv',
///   outputPath: '/path/to/audio.wav',
///   onProgress: (progress) => print('${(progress * 100).round()}%'),
/// );
/// ```
class TinyWavpackDecoder {
  /// Creates a decoder.
  ///
  /// [runner] replaces the FFI-backed native layer in tests; production code
  /// should use the default.
  TinyWavpackDecoder({@visibleForTesting NativeDecodeRunner? runner})
      : _runner = runner ?? const FfiDecodeRunner();

  final NativeDecodeRunner _runner;

  /// Tail of the process-wide decode queue.
  ///
  /// The native decoder keeps static state (a static `WavpackContext` and a
  /// static `FILE*`), so decodes must never overlap anywhere in the process —
  /// this is deliberately static, not per instance.
  static Future<void> _queueTail = Future<void>.value();

  /// Output bit depths supported by the native decoder.
  static const List<int> _supportedBitsPerSample = [8, 16, 24, 32];

  /// Decodes the WavPack file at [inputPath] into a PCM WAV file (canonical
  /// 44-byte header) at [outputPath], overwriting it if it exists.
  ///
  /// [maxSamples] caps the number of samples per channel to decode; the
  /// default `-1` decodes the entire file. Must be `>= -1`.
  ///
  /// [bitsPerSample] selects the output bit depth and must be 8, 16
  /// (default), 24, or 32.
  ///
  /// [onProgress], when provided, is called on the caller's isolate with
  /// monotonically increasing values in `(0.0, 1.0]`. A terminal `1.0` is
  /// always delivered on success, and no callbacks occur after the returned
  /// future completes. Granularity is one callback per 4096 decoded frames.
  ///
  /// Throws an [ArgumentError] for invalid [bitsPerSample] or [maxSamples],
  /// and a [WavpackDecodeException] when decoding fails (missing input file,
  /// invalid or corrupt WavPack data, CRC errors, unwritable output, or an
  /// unsupported stream version — the decoder handles WavPack 4.2–4.10).
  Future<void> decode({
    required String inputPath,
    required String outputPath,
    int maxSamples = -1,
    int bitsPerSample = 16,
    void Function(double progress)? onProgress,
  }) {
    if (!_supportedBitsPerSample.contains(bitsPerSample)) {
      throw ArgumentError.value(
        bitsPerSample,
        'bitsPerSample',
        'must be 8, 16, 24, or 32',
      );
    }
    if (maxSamples < -1) {
      throw ArgumentError.value(maxSamples, 'maxSamples', 'must be >= -1');
    }

    // Chain onto the queue, isolating waiters from each other's errors: the
    // caller gets this decode's outcome, while the queue itself always stays
    // alive for the next decode.
    final completer = Completer<void>();
    _queueTail = _queueTail.then((_) {
      return _decodeLocked(
        inputPath,
        outputPath,
        maxSamples,
        bitsPerSample,
        onProgress,
      ).then(completer.complete, onError: completer.completeError);
    });
    return completer.future;
  }

  Future<void> _decodeLocked(
    String inputPath,
    String outputPath,
    int maxSamples,
    int bitsPerSample,
    void Function(double progress)? onProgress,
  ) async {
    if (!File(inputPath).existsSync()) {
      throw WavpackDecodeException('Input file does not exist: $inputPath');
    }

    var lastProgress = 0.0;
    var done = false;
    void forwardProgress(double progress) {
      if (done || onProgress == null) {
        return;
      }
      final clamped = progress.clamp(0.0, 1.0);
      if (clamped <= lastProgress) {
        return; // Keep the stream strictly increasing.
      }
      lastProgress = clamped;
      onProgress(clamped);
    }

    final request = NativeDecodeRequest(
      inputPath: inputPath,
      outputPath: outputPath,
      maxSamples: maxSamples,
      bitsPerSample: bitsPerSample,
    );

    try {
      final result = await _runner.run(request, forwardProgress);
      if (!result.success) {
        throw WavpackDecodeException(
          result.error.isEmpty ? 'Unknown decode error' : result.error,
        );
      }
      forwardProgress(1.0);
    } finally {
      // Suppress any progress messages still in flight (the FFI runner's
      // NativeCallable delivers asynchronously) so callers never observe a
      // callback after the future completes.
      done = true;
    }
  }
}
