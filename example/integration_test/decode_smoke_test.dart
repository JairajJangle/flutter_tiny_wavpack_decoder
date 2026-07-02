// On-device smoke test: decodes the bundled WavPack sample through the
// platform-built native library (not the host test build) and checks the
// output. Run with e.g.:
//   flutter test integration_test -d macos
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiny_wavpack_decoder/flutter_tiny_wavpack_decoder.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('decodes the bundled sample end-to-end with progress', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync('ftwd_smoke');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final inputPath = '${tempDir.path}/sample.wv';
    final outputPath = '${tempDir.path}/sample.wav';
    final asset = await rootBundle.load('assets/sine_stereo_16bit_44100.wv');
    File(inputPath).writeAsBytesSync(asset.buffer.asUint8List());

    final progress = <double>[];
    await TinyWavpackDecoder().decode(
      inputPath: inputPath,
      outputPath: outputPath,
      onProgress: progress.add,
    );

    final output = File(outputPath);
    expect(output.existsSync(), isTrue);

    final bytes = output.readAsBytesSync();
    // 44-byte canonical header + 88200 frames * 2 channels * 2 bytes.
    expect(bytes.length, 44 + 88200 * 2 * 2);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');

    expect(progress, isNotEmpty);
    expect(progress.last, 1.0);
  });

  testWidgets('invalid input reports a WavpackDecodeException', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('ftwd_smoke_err');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final inputPath = '${tempDir.path}/garbage.wv';
    File(inputPath).writeAsStringSync('not wavpack at all');

    await expectLater(
      TinyWavpackDecoder().decode(
        inputPath: inputPath,
        outputPath: '${tempDir.path}/out.wav',
      ),
      throwsA(isA<WavpackDecodeException>()),
    );
  });
}
