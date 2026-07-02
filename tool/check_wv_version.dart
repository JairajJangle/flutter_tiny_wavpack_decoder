// Asserts that a .wv file's stream version is within the range supported by
// the vendored WavPack tiny decoder (MIN_STREAM_VERS 0x402 .. MAX_STREAM_VERS
// 0x410, see src/tiny-wavpack/lib/wavpack.h). The version is a little-endian
// uint16 at byte offset 8 of the WavPack block header ("wvpk" + ckSize).
//
// Usage: dart run tool/check_wv_version.dart <file.wv>
import 'dart:io';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('Usage: dart run tool/check_wv_version.dart <file.wv>');
    exit(64);
  }

  final bytes = File(args[0]).readAsBytesSync();
  if (bytes.length < 10 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'wvpk') {
    stderr.writeln('FAIL: ${args[0]} does not start with a "wvpk" block');
    exit(1);
  }

  final version = bytes[8] | (bytes[9] << 8);
  final hex = '0x${version.toRadixString(16)}';
  if (version < 0x402 || version > 0x410) {
    stderr.writeln('FAIL: stream version $hex outside supported 0x402..0x410');
    exit(1);
  }
  stdout.writeln('OK: ${args[0]} stream version $hex (supported)');
}
