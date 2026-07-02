import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiny_wavpack_decoder/flutter_tiny_wavpack_decoder.dart';

/// Scriptable in-memory stand-in for the native decode layer.
class FakeRunner implements NativeDecodeRunner {
  FakeRunner({
    this.result = const NativeDecodeResult(success: true, error: ''),
    this.progressScript = const <double>[],
    this.gate,
    this.error,
  });

  NativeDecodeResult result;
  List<double> progressScript;

  /// When set, [run] waits for this future before returning.
  Future<void>? gate;

  /// When set, [run] throws this instead of returning a result.
  Object? error;

  final List<NativeDecodeRequest> calls = <NativeDecodeRequest>[];

  @override
  Future<NativeDecodeResult> run(
    NativeDecodeRequest request,
    void Function(double progress) onProgress,
  ) async {
    calls.add(request);
    for (final value in progressScript) {
      onProgress(value);
    }
    if (gate != null) {
      await gate;
    }
    if (error != null) {
      throw error!;
    }
    return result;
  }
}

void main() {
  late Directory tempDir;
  late String existingInput;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ftwd_unit');
    existingInput = '${tempDir.path}/input.wv';
    File(existingInput).writeAsBytesSync(const <int>[0, 1, 2, 3]);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('argument validation', () {
    test('rejects bitsPerSample not in {8, 16, 24, 32} before touching the '
        'native layer', () {
      final runner = FakeRunner();
      final decoder = TinyWavpackDecoder(runner: runner);

      expect(
        () => decoder.decode(
          inputPath: existingInput,
          outputPath: '${tempDir.path}/out.wav',
          bitsPerSample: 12,
        ),
        throwsArgumentError,
      );
      expect(runner.calls, isEmpty);
    });

    test('accepts bitsPerSample 8, 16, 24, 32', () async {
      final runner = FakeRunner();
      final decoder = TinyWavpackDecoder(runner: runner);

      for (final bps in const [8, 16, 24, 32]) {
        await decoder.decode(
          inputPath: existingInput,
          outputPath: '${tempDir.path}/out.wav',
          bitsPerSample: bps,
        );
      }
      expect(runner.calls, hasLength(4));
    });

    test('rejects maxSamples < -1 before touching the native layer', () {
      final runner = FakeRunner();
      final decoder = TinyWavpackDecoder(runner: runner);

      expect(
        () => decoder.decode(
          inputPath: existingInput,
          outputPath: '${tempDir.path}/out.wav',
          maxSamples: -2,
        ),
        throwsArgumentError,
      );
      expect(runner.calls, isEmpty);
    });

    test('accepts maxSamples -1, 0 and positive values', () async {
      final runner = FakeRunner();
      final decoder = TinyWavpackDecoder(runner: runner);

      for (final samples in const [-1, 0, 4096]) {
        await decoder.decode(
          inputPath: existingInput,
          outputPath: '${tempDir.path}/out.wav',
          maxSamples: samples,
        );
      }
      expect(runner.calls, hasLength(3));
    });

    test('missing input file throws WavpackDecodeException naming the path '
        'without invoking the native layer', () async {
      final runner = FakeRunner();
      final decoder = TinyWavpackDecoder(runner: runner);
      final missing = '${tempDir.path}/nope.wv';

      await expectLater(
        decoder.decode(inputPath: missing, outputPath: '${tempDir.path}/out.wav'),
        throwsA(
          isA<WavpackDecodeException>()
              .having((e) => e.message, 'message', contains(missing)),
        ),
      );
      expect(runner.calls, isEmpty);
    });
  });

  group('request marshaling', () {
    test('forwards paths and options to the native layer unchanged', () async {
      final runner = FakeRunner();
      final decoder = TinyWavpackDecoder(runner: runner);

      await decoder.decode(
        inputPath: existingInput,
        outputPath: '${tempDir.path}/out.wav',
        maxSamples: 1234,
        bitsPerSample: 24,
      );

      final request = runner.calls.single;
      expect(request.inputPath, existingInput);
      expect(request.outputPath, '${tempDir.path}/out.wav');
      expect(request.maxSamples, 1234);
      expect(request.bitsPerSample, 24);
    });

    test('applies defaults maxSamples -1 and bitsPerSample 16', () async {
      final runner = FakeRunner();
      final decoder = TinyWavpackDecoder(runner: runner);

      await decoder.decode(
        inputPath: existingInput,
        outputPath: '${tempDir.path}/out.wav',
      );

      final request = runner.calls.single;
      expect(request.maxSamples, -1);
      expect(request.bitsPerSample, 16);
    });
  });

  group('error mapping', () {
    test('native failure surfaces its message as WavpackDecodeException',
        () async {
      final runner = FakeRunner(
        result:
            const NativeDecodeResult(success: false, error: 'Invalid WavPack file'),
      );
      final decoder = TinyWavpackDecoder(runner: runner);

      await expectLater(
        decoder.decode(
          inputPath: existingInput,
          outputPath: '${tempDir.path}/out.wav',
        ),
        throwsA(
          isA<WavpackDecodeException>()
              .having((e) => e.message, 'message', 'Invalid WavPack file'),
        ),
      );
    });

    test('native failure with empty message maps to "Unknown decode error"',
        () async {
      final runner =
          FakeRunner(result: const NativeDecodeResult(success: false, error: ''));
      final decoder = TinyWavpackDecoder(runner: runner);

      await expectLater(
        decoder.decode(
          inputPath: existingInput,
          outputPath: '${tempDir.path}/out.wav',
        ),
        throwsA(
          isA<WavpackDecodeException>()
              .having((e) => e.message, 'message', 'Unknown decode error'),
        ),
      );
    });

    test('unexpected errors from the native layer propagate as-is', () async {
      final runner = FakeRunner(error: StateError('isolate died'));
      final decoder = TinyWavpackDecoder(runner: runner);

      await expectLater(
        decoder.decode(
          inputPath: existingInput,
          outputPath: '${tempDir.path}/out.wav',
        ),
        throwsStateError,
      );
    });
  });

  group('progress reporting', () {
    test('clamps, drops non-increasing values and guarantees terminal 1.0',
        () async {
      final runner = FakeRunner(progressScript: [0.25, 0.2, 0.5, 1.2]);
      final decoder = TinyWavpackDecoder(runner: runner);
      final seen = <double>[];

      await decoder.decode(
        inputPath: existingInput,
        outputPath: '${tempDir.path}/out.wav',
        onProgress: seen.add,
      );

      expect(seen, [0.25, 0.5, 1.0]);
    });

    test('success with no native progress still reports exactly [1.0]',
        () async {
      final runner = FakeRunner();
      final decoder = TinyWavpackDecoder(runner: runner);
      final seen = <double>[];

      await decoder.decode(
        inputPath: existingInput,
        outputPath: '${tempDir.path}/out.wav',
        onProgress: seen.add,
      );

      expect(seen, [1.0]);
    });

    test('failure does not synthesize a terminal 1.0', () async {
      final runner = FakeRunner(
        progressScript: [0.25],
        result: const NativeDecodeResult(success: false, error: 'CRC errors'),
      );
      final decoder = TinyWavpackDecoder(runner: runner);
      final seen = <double>[];

      await expectLater(
        decoder.decode(
          inputPath: existingInput,
          outputPath: '${tempDir.path}/out.wav',
          onProgress: seen.add,
        ),
        throwsA(isA<WavpackDecodeException>()),
      );
      expect(seen, [0.25]);
    });

    test('decode without onProgress succeeds', () async {
      final runner = FakeRunner(progressScript: [0.5]);
      final decoder = TinyWavpackDecoder(runner: runner);

      await decoder.decode(
        inputPath: existingInput,
        outputPath: '${tempDir.path}/out.wav',
      );
    });
  });

  group('decode serialization', () {
    test('a second decode only reaches the native layer after the first '
        'completes', () async {
      final gate = Completer<void>();
      final runner = FakeRunner(gate: gate.future);
      final decoder = TinyWavpackDecoder(runner: runner);

      final first = decoder.decode(
        inputPath: existingInput,
        outputPath: '${tempDir.path}/out1.wav',
      );
      // Let the first decode reach the native layer and block on the gate.
      await Future<void>.delayed(Duration.zero);
      expect(runner.calls, hasLength(1));

      final second = decoder.decode(
        inputPath: existingInput,
        outputPath: '${tempDir.path}/out2.wav',
      );
      await Future<void>.delayed(Duration.zero);
      expect(runner.calls, hasLength(1),
          reason: 'second decode must wait for the first');

      runner.gate = null;
      gate.complete();
      await Future.wait([first, second]);
      expect(runner.calls, hasLength(2));
      expect(runner.calls[0].outputPath, endsWith('out1.wav'));
      expect(runner.calls[1].outputPath, endsWith('out2.wav'));
    });

    test('decodes are serialized across decoder instances (the native '
        'decoder state is process-wide)', () async {
      final gate = Completer<void>();
      final runner = FakeRunner(gate: gate.future);
      final first = TinyWavpackDecoder(runner: runner)
          .decode(inputPath: existingInput, outputPath: '${tempDir.path}/a.wav');
      await Future<void>.delayed(Duration.zero);

      final otherRunner = FakeRunner();
      final second = TinyWavpackDecoder(runner: otherRunner)
          .decode(inputPath: existingInput, outputPath: '${tempDir.path}/b.wav');
      await Future<void>.delayed(Duration.zero);
      expect(otherRunner.calls, isEmpty,
          reason: 'the queue is shared process-wide, not per instance');

      runner.gate = null;
      gate.complete();
      await Future.wait([first, second]);
      expect(otherRunner.calls, hasLength(1));
    });

    test('a failed decode does not wedge the queue', () async {
      final runner = FakeRunner(
        result: const NativeDecodeResult(success: false, error: 'boom'),
      );
      final decoder = TinyWavpackDecoder(runner: runner);

      await expectLater(
        decoder.decode(
          inputPath: existingInput,
          outputPath: '${tempDir.path}/out.wav',
        ),
        throwsA(isA<WavpackDecodeException>()),
      );

      runner.result = const NativeDecodeResult(success: true, error: '');
      await decoder.decode(
        inputPath: existingInput,
        outputPath: '${tempDir.path}/out.wav',
      );
      expect(runner.calls, hasLength(2));
    });
  });

  group('WavpackDecodeException', () {
    test('toString includes the message', () {
      expect(
        const WavpackDecodeException('Cannot open input file').toString(),
        'WavpackDecodeException: Cannot open input file',
      );
    });
  });
}
