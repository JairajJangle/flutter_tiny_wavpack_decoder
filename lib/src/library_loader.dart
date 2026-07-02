import 'dart:ffi';
import 'dart:io';

const String _libName = 'flutter_tiny_wavpack_decoder';

/// Test hook: absolute path of a host-built copy of the native library.
///
/// When set, [openFtwdLibrary] opens it instead of the platform-bundled
/// library. Only tests should assign this (the package's own FFI runner
/// reads it to propagate the override into worker isolates, since globals
/// are per-isolate). Not part of the public API; this library is not
/// exported.
String? ftwdLibraryOverridePath;

/// Opens the native decoder library for the current platform.
DynamicLibrary openFtwdLibrary() {
  final override = ftwdLibraryOverridePath;
  if (override != null) {
    return DynamicLibrary.open(override);
  }
  if (Platform.isIOS || Platform.isMacOS) {
    try {
      return DynamicLibrary.open('$_libName.framework/$_libName');
    } on ArgumentError {
      // The pod may be statically linked into the app binary.
      return DynamicLibrary.process();
    }
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}
