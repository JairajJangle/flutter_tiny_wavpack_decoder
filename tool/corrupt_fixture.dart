// Produces the corrupt-CRC fixture: copies a .wv file and XORs 16 bytes
// with 0xFF starting at 60% of the file length (deep inside the sample
// data, past all headers) so the decoder hits CRC errors mid-stream.
//
// Usage: dart run tool/corrupt_fixture.dart <input.wv> <output.wv>
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/corrupt_fixture.dart <in.wv> <out.wv>',
    );
    exit(64);
  }

  final bytes = File(args[0]).readAsBytesSync();
  final start = (bytes.length * 0.6).floor();
  for (var i = start; i < start + 16 && i < bytes.length; i++) {
    bytes[i] ^= 0xFF;
  }
  File(args[1]).writeAsBytesSync(bytes);
  stdout.writeln('Wrote ${args[1]} (flipped 16 bytes at offset $start)');
}
