// Native (dart:ffi + dart:io) platform defaults. Selected by the
// conditional import in decoder.dart; keep the top-level API identical to
// platform_defaults_web.dart and platform_defaults_stub.dart.
import 'dart:io';

import 'bytes_decode_runner.dart';
import 'ffi_bytes_decode_runner.dart';
import 'ffi_decode_runner.dart';
import 'native_decode_runner.dart';

/// Whether path-based [TinyWavpackDecoder.decode] works on this platform.
const bool pathDecodingSupported = true;

/// The default path-based runner: the bundled C decoder over `dart:ffi`.
NativeDecodeRunner defaultPathRunner() => const FfiDecodeRunner();

/// The default bytes runner: the bundled C decoder over `dart:ffi`.
BytesDecodeRunner defaultBytesRunner() => const FfiBytesDecodeRunner();

/// Whether the input file exists (pre-flight check before decoding).
bool inputFileExists(String path) => File(path).existsSync();
