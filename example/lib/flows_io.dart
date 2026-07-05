// Native decode flows: path-based API writing real files. The web
// counterpart (flows_web.dart) is selected by the conditional import in
// main.dart; keep both files' top-level APIs identical.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_tiny_wavpack_decoder/flutter_tiny_wavpack_decoder.dart';

import 'decode_outcome.dart';

/// Whether [playWav]/[downloadWav] do anything on this platform.
const bool supportsWavActions = false;

/// Decodes the bundled sample asset via the path-based API.
Future<DecodeOutcome?> decodeSampleFlow(
  TinyWavpackDecoder decoder,
  Uint8List sampleBytes,
  void Function(double progress) onProgress,
) async {
  final tempDir = Directory.systemTemp.createTempSync('wavpack_example');
  final inputPath = '${tempDir.path}/sample.wv';
  File(inputPath).writeAsBytesSync(sampleBytes);
  final outputPath = '${tempDir.path}/sample.wav';
  await decoder.decode(
    inputPath: inputPath,
    outputPath: outputPath,
    onProgress: onProgress,
  );
  final size = File(outputPath).lengthSync();
  return DecodeOutcome(summary: '$outputPath\n$size bytes');
}

/// Lets the user pick a `.wv` file and decodes it via the path-based API.
Future<DecodeOutcome?> pickAndDecodeFlow(
  TinyWavpackDecoder decoder,
  void Function(double progress) onProgress,
) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['wv'],
  );
  final inputPath = result?.files.single.path;
  if (inputPath == null) {
    return null; // User cancelled the picker.
  }
  final tempDir = Directory.systemTemp.createTempSync('wavpack_example');
  final baseName = inputPath.split(Platform.pathSeparator).last;
  final stem = baseName.endsWith('.wv')
      ? baseName.substring(0, baseName.length - 3)
      : baseName;
  final outputPath = '${tempDir.path}/$stem.wav';
  await decoder.decode(
    inputPath: inputPath,
    outputPath: outputPath,
    onProgress: onProgress,
  );
  final size = File(outputPath).lengthSync();
  return DecodeOutcome(summary: '$outputPath\n$size bytes');
}

/// No-op on native platforms (WAV playback would need an audio plugin).
void playWav(Uint8List wavBytes) {}

/// No-op on native platforms (the decoded file is already on disk).
void downloadWav(Uint8List wavBytes, String name) {}
