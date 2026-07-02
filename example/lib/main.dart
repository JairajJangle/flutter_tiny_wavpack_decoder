import 'dart:io';

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

  Future<void> _decode() async {
    setState(() {
      _decoding = true;
      _progress = 0;
      _outputSummary = null;
      _error = null;
      _elapsed = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final tempDir = Directory.systemTemp.createTempSync('wavpack_example');
      final inputPath = '${tempDir.path}/sample.wv';
      final outputPath = '${tempDir.path}/sample.wav';

      final asset = await rootBundle.load(_asset);
      File(inputPath).writeAsBytesSync(asset.buffer.asUint8List());

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
              'Decodes the bundled sample ($_asset) to a PCM WAV file.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _decoding ? null : _decode,
              icon: const Icon(Icons.music_note),
              label: Text(_decoding ? 'Decoding…' : 'Decode sample'),
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
