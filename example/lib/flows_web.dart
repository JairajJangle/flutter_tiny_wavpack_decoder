// Web decode flows: everything happens in memory with decodeBytes (the
// decode itself runs as WASM in a Web Worker). The native counterpart
// (flows_io.dart) is selected by the conditional import in main.dart; keep
// both files' top-level APIs identical.
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_tiny_wavpack_decoder/flutter_tiny_wavpack_decoder.dart';
import 'package:web/web.dart' as web;

import 'decode_outcome.dart';

/// Whether [playWav]/[downloadWav] do anything on this platform.
const bool supportsWavActions = true;

/// Decodes the bundled sample asset in memory.
Future<DecodeOutcome?> decodeSampleFlow(
  TinyWavpackDecoder decoder,
  Uint8List sampleBytes,
  void Function(double progress) onProgress,
) async {
  final wav = await decoder.decodeBytes(sampleBytes, onProgress: onProgress);
  return DecodeOutcome(
    summary: 'Decoded in memory via WASM Web Worker\n${wav.length} bytes',
    wavBytes: wav,
    wavName: 'sample.wav',
  );
}

/// Lets the user pick a `.wv` file and decodes its bytes in memory.
Future<DecodeOutcome?> pickAndDecodeFlow(
  TinyWavpackDecoder decoder,
  void Function(double progress) onProgress,
) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['wv'],
    withData: true,
  );
  final file = result?.files.single;
  final bytes = file?.bytes;
  if (file == null || bytes == null) {
    return null; // User cancelled the picker.
  }
  final wav = await decoder.decodeBytes(bytes, onProgress: onProgress);
  final stem = file.name.endsWith('.wv')
      ? file.name.substring(0, file.name.length - 3)
      : file.name;
  return DecodeOutcome(
    summary: 'Decoded in memory via WASM Web Worker\n${wav.length} bytes',
    wavBytes: wav,
    wavName: '$stem.wav',
  );
}

String _createBlobUrl(Uint8List wavBytes) {
  final blob = web.Blob(
    <web.BlobPart>[wavBytes.toJS].toJS,
    web.BlobPropertyBag(type: 'audio/wav'),
  );
  return web.URL.createObjectURL(blob);
}

/// Plays the decoded WAV through an HTMLAudioElement.
void playWav(Uint8List wavBytes) {
  final audio = web.document.createElement('audio') as web.HTMLAudioElement;
  audio.src = _createBlobUrl(wavBytes);
  audio.play();
}

/// Triggers a browser download of the decoded WAV.
void downloadWav(Uint8List wavBytes, String name) {
  final url = _createBlobUrl(wavBytes);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = name;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
