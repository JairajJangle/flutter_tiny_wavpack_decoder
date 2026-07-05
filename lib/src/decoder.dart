import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'bytes_decode_runner.dart';
import 'exceptions.dart';
import 'native_decode_runner.dart';
import 'platform_defaults_stub.dart'
    if (dart.library.ffi) 'platform_defaults_io.dart'
    if (dart.library.js_interop) 'platform_defaults_web.dart'
    as platform;

/// Decodes WavPack (`.wv`) audio to PCM `.wav` using the bundled WavPack
/// 4.40 "tiny decoder" C library — over `dart:ffi` on native platforms, and
/// as WASM inside a Web Worker on the web.
///
/// [decode] converts a file on disk to a file on disk (native platforms
/// only); [decodeBytes] converts in-memory bytes to in-memory bytes and
/// works everywhere, including the web. Neither blocks the calling (UI)
/// isolate: the decode runs in a worker isolate (native) or a Web Worker
/// (web). The native decoder is **not reentrant**: all decodes in the
/// process are automatically serialized through one internal queue shared
/// by every [TinyWavpackDecoder] instance, so concurrent calls are safe but
/// run one at a time.
///
/// ```dart
/// final decoder = TinyWavpackDecoder();
/// await decoder.decode(
///   inputPath: '/path/to/audio.wv',
///   outputPath: '/path/to/audio.wav',
///   onProgress: (progress) => print('${(progress * 100).round()}%'),
/// );
///
/// // Or, on any platform including web:
/// final wavBytes = await decoder.decodeBytes(wvBytes);
/// ```
class TinyWavpackDecoder {
  /// Creates a decoder.
  ///
  /// [runner] and [bytesRunner] replace the platform-backed decode layers in
  /// tests; production code should use the defaults.
  TinyWavpackDecoder({
    @visibleForTesting NativeDecodeRunner? runner,
    @visibleForTesting BytesDecodeRunner? bytesRunner,
  }) : _runner = runner,
       _bytesRunner = bytesRunner;

  final NativeDecodeRunner? _runner;
  final BytesDecodeRunner? _bytesRunner;

  /// Tail of the process-wide decode queue.
  ///
  /// The native decoder keeps static state (a static `WavpackContext` and a
  /// static input cursor), so decodes must never overlap anywhere in the
  /// process; this is deliberately static, not per instance.
  static Future<void> _queueTail = Future<void>.value();

  /// Output bit depths supported by the native decoder.
  static const List<int> _supportedBitsPerSample = [8, 16, 24, 32];

  /// Decodes the WavPack file at [inputPath] into a PCM WAV file (canonical
  /// 44-byte header) at [outputPath], overwriting it if it exists.
  ///
  /// Not available on the web (browsers have no filesystem): throws an
  /// [UnsupportedError] there — use [decodeBytes] instead.
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
  /// unsupported stream version; the decoder handles WavPack 4.2-4.10).
  Future<void> decode({
    required String inputPath,
    required String outputPath,
    int maxSamples = -1,
    int bitsPerSample = 16,
    void Function(double progress)? onProgress,
  }) {
    _validateOptions(maxSamples, bitsPerSample);
    // Resolving the default runner throws UnsupportedError on the web, so
    // callers find out synchronously rather than via a failed future.
    final runner = _runner ?? platform.defaultPathRunner();
    return _enqueue(() async {
      if (!platform.inputFileExists(inputPath)) {
        throw WavpackDecodeException('Input file does not exist: $inputPath');
      }
      final progress = _ProgressGate(onProgress);
      try {
        final result = await runner.run(
          NativeDecodeRequest(
            inputPath: inputPath,
            outputPath: outputPath,
            maxSamples: maxSamples,
            bitsPerSample: bitsPerSample,
          ),
          progress.forward,
        );
        if (!result.success) {
          throw WavpackDecodeException(
            result.error.isEmpty ? 'Unknown decode error' : result.error,
          );
        }
        progress.forward(1.0);
      } finally {
        progress.close();
      }
    });
  }

  /// Decodes in-memory WavPack bytes [input] and returns the complete WAV
  /// file bytes (canonical 44-byte header + PCM data).
  ///
  /// Works on every platform, including the web (where the decode runs as
  /// WASM inside a Web Worker).
  ///
  /// [maxSamples], [bitsPerSample], and [onProgress] behave exactly as in
  /// [decode].
  ///
  /// Throws an [ArgumentError] for empty [input] or invalid options, and a
  /// [WavpackDecodeException] when decoding fails.
  Future<Uint8List> decodeBytes(
    Uint8List input, {
    int maxSamples = -1,
    int bitsPerSample = 16,
    void Function(double progress)? onProgress,
  }) {
    _validateOptions(maxSamples, bitsPerSample);
    if (input.isEmpty) {
      throw ArgumentError.value(input, 'input', 'must not be empty');
    }
    final runner = _bytesRunner ?? platform.defaultBytesRunner();
    return _enqueue(() async {
      final progress = _ProgressGate(onProgress);
      try {
        final result = await runner.run(
          BytesDecodeRequest(
            input: input,
            maxSamples: maxSamples,
            bitsPerSample: bitsPerSample,
          ),
          progress.forward,
        );
        final output = result.output;
        if (output == null) {
          throw WavpackDecodeException(
            result.error.isEmpty ? 'Unknown decode error' : result.error,
          );
        }
        progress.forward(1.0);
        return output;
      } finally {
        progress.close();
      }
    });
  }

  static void _validateOptions(int maxSamples, int bitsPerSample) {
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
  }

  /// Chains [task] onto the process-wide queue, isolating waiters from each
  /// other's errors: the caller gets this decode's outcome, while the queue
  /// itself always stays alive for the next decode.
  static Future<T> _enqueue<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queueTail = _queueTail.then((_) {
      return task().then(completer.complete, onError: completer.completeError);
    });
    return completer.future;
  }
}

/// Filters a raw progress stream: clamps to `[0, 1]`, keeps it strictly
/// increasing, and suppresses anything arriving after [close] (progress
/// messages can still be in flight when the decode future completes, since
/// both the FFI listener callback and Web Worker messages deliver
/// asynchronously).
final class _ProgressGate {
  _ProgressGate(this._onProgress);

  final void Function(double progress)? _onProgress;
  var _last = 0.0;
  var _closed = false;

  void forward(double progress) {
    final onProgress = _onProgress;
    if (_closed || onProgress == null) {
      return;
    }
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= _last) {
      return;
    }
    _last = clamped;
    onProgress(clamped);
  }

  void close() {
    _closed = true;
  }
}
