@Tags(['ffi'])
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiny_wavpack_decoder/flutter_tiny_wavpack_decoder.dart';
import 'package:flutter_tiny_wavpack_decoder/src/library_loader.dart';

const _fixture = 'test/fixtures/sine_stereo_16bit_44100.wv';
const _reference = 'test/fixtures/reference/sine_stereo_16bit_44100.wav';
const _frames = 88200; // 2.0 s at 44.1 kHz
const _channels = 2;

/// Locates the host library produced by tool/build_host_lib.sh, or null.
String? _hostLibraryPath() {
  const candidates = [
    'build/host/libflutter_tiny_wavpack_decoder.dylib',
    'build/host/libflutter_tiny_wavpack_decoder.so',
    'build/host/Release/flutter_tiny_wavpack_decoder.dll',
    'build/host/flutter_tiny_wavpack_decoder.dll',
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return File(candidate).absolute.path;
    }
  }
  return null;
}

/// Asserts byte equality with a useful message on first mismatch.
void _expectBytesEqual(Uint8List actual, Uint8List expected) {
  expect(actual.length, expected.length, reason: 'length mismatch');
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) {
      fail(
        'byte mismatch at offset $i: '
        'actual 0x${actual[i].toRadixString(16)} vs '
        'expected 0x${expected[i].toRadixString(16)}',
      );
    }
  }
}

({int channels, int sampleRate, int bitsPerSample, int dataSize})
_parseWavHeader(Uint8List bytes) {
  expect(bytes.length, greaterThanOrEqualTo(44));
  expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
  expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
  expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
  expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
  final data = ByteData.sublistView(bytes);
  return (
    channels: data.getUint16(22, Endian.little),
    sampleRate: data.getUint32(24, Endian.little),
    bitsPerSample: data.getUint16(34, Endian.little),
    dataSize: data.getUint32(40, Endian.little),
  );
}

/// Expected 24-bit payload for our 16-bit reference: the decoder emits the
/// (sign-extended) 16-bit value as 3 little-endian bytes without rescaling
/// (see format_samples in TinyWavPackDecoderInterface.c).
Uint8List _expected24BitPayload(Uint8List reference16) {
  final samples = reference16.length ~/ 2;
  final source = ByteData.sublistView(reference16);
  final out = Uint8List(samples * 3);
  for (var i = 0; i < samples; i++) {
    final value = source.getInt16(i * 2, Endian.little);
    out[i * 3] = value & 0xFF;
    out[i * 3 + 1] = (value >> 8) & 0xFF;
    out[i * 3 + 2] = (value >> 16) & 0xFF;
  }
  return out;
}

/// Expected 32-bit payload: the 16-bit value stored as int32, no rescaling.
Uint8List _expected32BitPayload(Uint8List reference16) {
  final samples = reference16.length ~/ 2;
  final source = ByteData.sublistView(reference16);
  final out = Uint8List(samples * 4);
  final dest = ByteData.sublistView(out);
  for (var i = 0; i < samples; i++) {
    dest.setInt32(i * 4, source.getInt16(i * 2, Endian.little), Endian.little);
  }
  return out;
}

void main() {
  final libraryPath = _hostLibraryPath();

  if (libraryPath == null) {
    test('host library not built', () {
      markTestSkipped(
        'Skipping FFI tests: run tool/build_host_lib.sh to build the host '
        'native library first.',
      );
    });
    return;
  }

  late Directory tempDir;
  final decoder = TinyWavpackDecoder();
  final referencePayload = Uint8List.fromList(
    File(_reference).readAsBytesSync().sublist(44),
  );

  setUpAll(() {
    ftwdLibraryOverridePath = libraryPath;
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ftwd_ffi');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('lossless round-trip', () {
    test('16-bit decode reproduces the reference WAV byte-exactly', () async {
      final outputPath = '${tempDir.path}/out.wav';
      await decoder.decode(inputPath: _fixture, outputPath: outputPath);

      final decoded = File(outputPath).readAsBytesSync();
      final header = _parseWavHeader(decoded);
      expect(header.channels, _channels);
      expect(header.sampleRate, 44100);
      expect(header.bitsPerSample, 16);
      expect(header.dataSize, _frames * _channels * 2);

      _expectBytesEqual(decoded, File(_reference).readAsBytesSync());
    });

    test('maxSamples caps the decoded frames', () async {
      final outputPath = '${tempDir.path}/out.wav';
      await decoder.decode(
        inputPath: _fixture,
        outputPath: outputPath,
        maxSamples: 4096,
      );

      final decoded = File(outputPath).readAsBytesSync();
      final header = _parseWavHeader(decoded);
      expect(header.dataSize, 4096 * _channels * 2);
      _expectBytesEqual(
        Uint8List.sublistView(decoded, 44),
        Uint8List.sublistView(referencePayload, 0, 4096 * _channels * 2),
      );
    });

    test(
      '24-bit output carries the 16-bit values unscaled in 3 bytes',
      () async {
        final outputPath = '${tempDir.path}/out.wav';
        await decoder.decode(
          inputPath: _fixture,
          outputPath: outputPath,
          bitsPerSample: 24,
        );

        final decoded = File(outputPath).readAsBytesSync();
        final header = _parseWavHeader(decoded);
        expect(header.bitsPerSample, 24);
        expect(header.dataSize, _frames * _channels * 3);
        _expectBytesEqual(
          Uint8List.sublistView(decoded, 44),
          _expected24BitPayload(referencePayload),
        );
      },
    );

    test('32-bit output carries the 16-bit values unscaled as int32', () async {
      final outputPath = '${tempDir.path}/out.wav';
      await decoder.decode(
        inputPath: _fixture,
        outputPath: outputPath,
        bitsPerSample: 32,
      );

      final decoded = File(outputPath).readAsBytesSync();
      final header = _parseWavHeader(decoded);
      expect(header.bitsPerSample, 32);
      expect(header.dataSize, _frames * _channels * 4);
      _expectBytesEqual(
        Uint8List.sublistView(decoded, 44),
        _expected32BitPayload(referencePayload),
      );
    });
  });

  group('error paths', () {
    test('non-WavPack input throws with the native open error', () async {
      await expectLater(
        decoder.decode(
          inputPath: 'test/fixtures/not_wavpack.wv',
          outputPath: '${tempDir.path}/out.wav',
        ),
        throwsA(
          isA<WavpackDecodeException>().having(
            (e) => e.message,
            'message',
            isNotEmpty,
          ),
        ),
      );
      expect(File('${tempDir.path}/out.wav').existsSync(), isFalse);
    });

    test('truncated input throws', () async {
      await expectLater(
        decoder.decode(
          inputPath: 'test/fixtures/truncated.wv',
          outputPath: '${tempDir.path}/out.wav',
        ),
        throwsA(isA<WavpackDecodeException>()),
      );
    });

    test('corrupted stream reports CRC errors', () async {
      await expectLater(
        decoder.decode(
          inputPath: 'test/fixtures/corrupt_crc.wv',
          outputPath: '${tempDir.path}/out.wav',
        ),
        throwsA(
          isA<WavpackDecodeException>().having(
            (e) => e.message,
            'message',
            contains('CRC'),
          ),
        ),
      );
    });

    test('unwritable output path reports "Cannot open output file"', () async {
      await expectLater(
        decoder.decode(
          inputPath: _fixture,
          outputPath: '${tempDir.path}/no_such_dir/out.wav',
        ),
        throwsA(
          isA<WavpackDecodeException>().having(
            (e) => e.message,
            'message',
            contains('Cannot open output file'),
          ),
        ),
      );
    });
  });

  group('progress', () {
    test('onProgress capturing unsendable state must not leak into the worker '
        'isolate spawn message', () async {
      // Regression: closures created in the same scope as the Isolate.run
      // worker closure share a capture context, so onProgress (which in a
      // real app references widget State / WidgetsFlutterBinding) became
      // transitively reachable from the spawn message and Isolate.run threw
      // "object is unsendable". A ReceivePort reproduces the unsendable
      // capture deterministically.
      final unsendable = ReceivePort();
      addTearDown(unsendable.close);
      final seen = <double>[];

      await decoder.decode(
        inputPath: _fixture,
        outputPath: '${tempDir.path}/out.wav',
        onProgress: (progress) {
          // Reference the ReceivePort so the callback's context holds it.
          unsendable.hashCode;
          seen.add(progress);
        },
      );

      expect(seen, isNotEmpty);
      expect(seen.last, 1.0);
    });

    test(
      'reports granular, strictly increasing values ending at 1.0',
      () async {
        final seen = <double>[];
        await decoder.decode(
          inputPath: _fixture,
          outputPath: '${tempDir.path}/out.wav',
          onProgress: seen.add,
        );

        // 88200 frames at one callback per 4096-frame block = 22 native
        // callbacks; a few may race decode completion and be suppressed.
        expect(seen.length, greaterThanOrEqualTo(10));
        expect(seen.last, 1.0);
        for (final value in seen) {
          expect(value, greaterThan(0.0));
          expect(value, lessThanOrEqualTo(1.0));
        }
        for (var i = 1; i < seen.length; i++) {
          expect(
            seen[i],
            greaterThan(seen[i - 1]),
            reason: 'progress must be strictly increasing',
          );
        }

        // No callbacks may arrive after the future completes.
        final countAtCompletion = seen.length;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(seen.length, countAtCompletion);
      },
    );
  });

  group('concurrency', () {
    test('parallel decode calls are serialized and all produce byte-exact '
        'output', () async {
      final outputs = [
        '${tempDir.path}/a.wav',
        '${tempDir.path}/b.wav',
        '${tempDir.path}/c.wav',
      ];

      await Future.wait([
        for (final output in outputs)
          decoder.decode(inputPath: _fixture, outputPath: output),
      ]);

      final reference = File(_reference).readAsBytesSync();
      for (final output in outputs) {
        _expectBytesEqual(File(output).readAsBytesSync(), reference);
      }
    });
  });
}
