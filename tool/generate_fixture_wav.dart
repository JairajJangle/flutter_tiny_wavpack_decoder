// Writes the deterministic reference WAV used by the test fixtures:
// 44.1 kHz, stereo, 16-bit PCM, 2.0 s (88200 frames), canonical 44-byte
// header. Left channel is a 440 Hz sine, right channel 880 Hz, amplitude 0.5.
//
// Usage: dart run tool/generate_fixture_wav.dart <output.wav>
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 44100;
const int channels = 2;
const int bytesPerSample = 2;
const int frames = sampleRate * 2; // 2.0 seconds
const double amplitude = 0.5;
const double leftHz = 440.0;
const double rightHz = 880.0;

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/generate_fixture_wav.dart <output.wav>',
    );
    exit(64);
  }

  final dataSize = frames * channels * bytesPerSample;
  final bytes = BytesBuilder();

  final header = ByteData(44);
  void ascii(int offset, String tag) {
    for (var i = 0; i < tag.length; i++) {
      header.setUint8(offset + i, tag.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + dataSize, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // PCM fmt chunk size
  header.setUint16(20, 1, Endian.little); // audio format: PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  header.setUint16(32, channels * bytesPerSample, Endian.little);
  header.setUint16(34, bytesPerSample * 8, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, dataSize, Endian.little);
  bytes.add(header.buffer.asUint8List());

  final pcm = ByteData(dataSize);
  var offset = 0;
  for (var n = 0; n < frames; n++) {
    for (final hz in const [leftHz, rightHz]) {
      final value =
          (amplitude * math.sin(2 * math.pi * hz * n / sampleRate) * 32767)
              .round();
      pcm.setInt16(offset, value, Endian.little);
      offset += 2;
    }
  }
  bytes.add(pcm.buffer.asUint8List());

  File(args[0])
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes.takeBytes());
  stdout.writeln('Wrote ${args[0]} (${44 + dataSize} bytes)');
}
