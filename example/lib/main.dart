import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tiny_wavpack_decoder/flutter_tiny_wavpack_decoder.dart';

import 'decode_outcome.dart';
// Native platforms decode file-to-file over FFI; the web decodes bytes in a
// WASM Web Worker. Both files expose the same top-level flow functions.
import 'flows_io.dart' if (dart.library.js_interop) 'flows_web.dart'
    as flows;

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
  DecodeOutcome? _outcome;
  String? _error;
  Duration? _elapsed;

  /// Decodes the bundled sample asset.
  Future<void> _decodeSample() async {
    final asset = await rootBundle.load(_asset);
    await _runDecode(
      (onProgress) => flows.decodeSampleFlow(
        _decoder,
        asset.buffer.asUint8List(),
        onProgress,
      ),
    );
  }

  /// Lets the user pick a `.wv` file and decodes it.
  Future<void> _pickAndDecode() async {
    await _runDecode(
      (onProgress) => flows.pickAndDecodeFlow(_decoder, onProgress),
    );
  }

  /// Shared decode routine driving the progress bar and result summary.
  Future<void> _runDecode(
    Future<DecodeOutcome?> Function(void Function(double) onProgress) flow,
  ) async {
    setState(() {
      _decoding = true;
      _progress = 0;
      _outcome = null;
      _error = null;
      _elapsed = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final outcome = await flow(
        (progress) => setState(() => _progress = progress),
      );
      stopwatch.stop();
      setState(() {
        _outcome = outcome; // Null when the user cancelled the picker.
        _elapsed = outcome == null ? null : stopwatch.elapsed;
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
    final outcome = _outcome;
    final wavBytes = outcome?.wavBytes;
    return Scaffold(
      appBar: AppBar(title: const Text('Tiny WavPack Decoder')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Decode the bundled sample or pick your own .wv file '
              'to convert to a PCM WAV file'
              '${kIsWeb ? ' — decoded in a WASM Web Worker' : ''}.',
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
            if (outcome != null) ...[
              Text(
                'Decoded in ${_elapsed?.inMilliseconds} ms',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(outcome.summary, style: theme.textTheme.bodySmall),
              if (flows.supportsWavActions && wavBytes != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => flows.playWav(wavBytes),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => flows.downloadWav(
                        wavBytes,
                        outcome.wavName ?? 'decoded.wav',
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
