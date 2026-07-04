import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tiny_wavpack_decoder/flutter_tiny_wavpack_decoder.dart';

void main() {
  runApp(const DecoderExampleApp());
}

/// Demonstrates decoding the bundled WavPack sample with live progress.
class DecoderExampleApp extends StatelessWidget {
  const DecoderExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiny WavPack Decoder',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const DecoderPage(),
    );
  }
}

class DecoderPage extends StatefulWidget {
  const DecoderPage({super.key});

  @override
  State<DecoderPage> createState() => _DecoderPageState();
}

class _DecoderPageState extends State<DecoderPage> {
  static const _asset = 'assets/sine_stereo_16bit_44100.wv';

  final _decoder = TinyWavpackDecoder();

  bool _decoding = false;
  double _progress = 0;
  String? _outputSummary;
  String? _error;
  Duration? _elapsed;

  /// Decodes the bundled sample asset.
  Future<void> _decodeSample() async {
    final tempDir = Directory.systemTemp.createTempSync('wavpack_example');
    final inputPath = '${tempDir.path}/sample.wv';
    final asset = await rootBundle.load(_asset);
    File(inputPath).writeAsBytesSync(asset.buffer.asUint8List());
    await _runDecode(inputPath, '${tempDir.path}/sample.wav');
  }

  /// Lets the user pick a `.wv` file and decodes it.
  Future<void> _pickAndDecode() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wv'],
    );
    final inputPath = result?.files.single.path;
    if (inputPath == null) {
      return; // User cancelled the picker.
    }
    final tempDir = Directory.systemTemp.createTempSync('wavpack_example');
    final baseName = inputPath.split(Platform.pathSeparator).last;
    final stem = baseName.endsWith('.wv')
        ? baseName.substring(0, baseName.length - 3)
        : baseName;
    await _runDecode(inputPath, '${tempDir.path}/$stem.wav');
  }

  /// Shared decode routine driving the progress bar and result summary.
  Future<void> _runDecode(String inputPath, String outputPath) async {
    setState(() {
      _decoding = true;
      _progress = 0;
      _outputSummary = null;
      _error = null;
      _elapsed = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      await _decoder.decode(
        inputPath: inputPath,
        outputPath: outputPath,
        onProgress: (progress) => setState(() => _progress = progress),
      );

      stopwatch.stop();
      final size = File(outputPath).lengthSync();
      setState(() {
        _outputSummary = '$outputPath\n$size bytes';
        _elapsed = stopwatch.elapsed;
      });
    } on WavpackDecodeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _decoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tiny WavPack Decoder')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Decode the bundled sample or pick your own .wv file '
              'to convert to a PCM WAV file.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _decoding ? null : _decodeSample,
              icon: const Icon(Icons.music_note),
              label: Text(_decoding ? 'Decoding...' : 'Decode sample'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _decoding ? null : _pickAndDecode,
              icon: const Icon(Icons.folder_open),
              label: const Text('Pick .wv file'),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 8),
            Text('${(_progress * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 24),
            if (_error != null)
              Text(
                'Decode failed: $_error',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (_outputSummary != null) ...[
              Text(
                'Decoded in ${_elapsed?.inMilliseconds} ms',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(_outputSummary!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
