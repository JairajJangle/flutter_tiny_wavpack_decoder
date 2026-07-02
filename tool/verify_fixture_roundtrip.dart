// Fixture gate: decodes test/fixtures/sine_stereo_16bit_44100.wv with the
// REAL vendored C decoder (host library from tool/build_host_lib.sh) and
// requires the result to be byte-identical to the committed reference WAV.
// Proves both that ffmpeg's WavPack output is decodable by the tiny decoder
// and that the encode/decode round-trip is lossless.
//
// Usage: dart run tool/verify_fixture_roundtrip.dart
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _DecodeNative =
    Int Function(
      Pointer<Char>,
      Pointer<Char>,
      Int,
      Int,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Char>,
    );
typedef _DecodeDart =
    int Function(
      Pointer<Char>,
      Pointer<Char>,
      int,
      int,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Char>,
    );

void main() {
  final libPath = Platform.isMacOS
      ? 'build/host/libflutter_tiny_wavpack_decoder.dylib'
      : Platform.isWindows
      ? 'build/host/Release/flutter_tiny_wavpack_decoder.dll'
      : 'build/host/libflutter_tiny_wavpack_decoder.so';
  if (!File(libPath).existsSync()) {
    stderr.writeln(
      'FAIL: $libPath not built. Run tool/build_host_lib.sh first.',
    );
    exit(1);
  }

  final decode = DynamicLibrary.open(
    libPath,
  ).lookupFunction<_DecodeNative, _DecodeDart>('ftwd_decode');

  final outPath =
      '${Directory.systemTemp.createTempSync('ftwd_fixture').path}/roundtrip.wav';
  final input = 'test/fixtures/sine_stereo_16bit_44100.wv'.toNativeUtf8();
  final output = outPath.toNativeUtf8();
  final error = calloc<Char>(80);
  final ok = decode(
    input.cast(),
    output.cast(),
    -1,
    16,
    nullptr,
    nullptr,
    error,
  );
  final message = error.cast<Utf8>().toDartString();
  calloc.free(input);
  calloc.free(output);
  calloc.free(error);

  if (ok != 1) {
    stderr.writeln('FAIL: decode failed: $message');
    exit(1);
  }

  final decoded = File(outPath).readAsBytesSync();
  final reference = File(
    'test/fixtures/reference/sine_stereo_16bit_44100.wav',
  ).readAsBytesSync();
  if (decoded.length != reference.length) {
    stderr.writeln(
      'FAIL: length mismatch (decoded ${decoded.length} vs reference ${reference.length})',
    );
    exit(1);
  }
  for (var i = 0; i < decoded.length; i++) {
    if (decoded[i] != reference[i]) {
      stderr.writeln('FAIL: byte mismatch at offset $i');
      exit(1);
    }
  }
  stdout.writeln(
    'OK: lossless round-trip verified byte-exact (${decoded.length} bytes)',
  );
}
