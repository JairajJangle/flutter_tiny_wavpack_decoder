import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'library_loader.dart';
import 'native_decode_runner.dart';

/// [NativeDecodeRunner] backed by the bundled C decoder over `dart:ffi`.
///
/// The blocking `ftwd_decode` call runs in a short-lived worker isolate so
/// the calling isolate stays responsive. Progress flows through a
/// [NativeCallable.listener] created on the calling isolate: its native
/// function pointer is safe to invoke from the worker's thread, and each
/// invocation is posted to the calling isolate's event loop — which keeps
/// pumping while the worker is blocked inside the C call.
final class FfiDecodeRunner implements NativeDecodeRunner {
  /// Creates the FFI-backed runner.
  const FfiDecodeRunner();

  @override
  Future<NativeDecodeResult> run(
    NativeDecodeRequest request,
    void Function(double progress) onProgress,
  ) async {
    final callable = NativeCallable<FtwdProgressCallbackNative>.listener(
      (double progress, Pointer<Void> context) => onProgress(progress),
    );
    try {
      // The worker closure may only capture sendable values: strings, ints,
      // and the callback's raw address.
      final callbackAddress = callable.nativeFunction.address;
      final overridePath = ftwdLibraryOverridePath;
      final inputPath = request.inputPath;
      final outputPath = request.outputPath;
      final maxSamples = request.maxSamples;
      final bitsPerSample = request.bitsPerSample;

      return await Isolate.run(() {
        // Globals are per-isolate; propagate the test override.
        ftwdLibraryOverridePath = overridePath;
        final bindings = FtwdBindings(openFtwdLibrary());

        final nativeInput = inputPath.toNativeUtf8();
        final nativeOutput = outputPath.toNativeUtf8();
        final errorBuffer = calloc<Char>(ftwdErrorBufferSize);
        try {
          final status = bindings.decode(
            nativeInput.cast(),
            nativeOutput.cast(),
            maxSamples,
            bitsPerSample,
            Pointer.fromAddress(callbackAddress),
            nullptr,
            errorBuffer,
          );
          return NativeDecodeResult(
            success: status == 1,
            error: status == 1 ? '' : errorBuffer.cast<Utf8>().toDartString(),
          );
        } finally {
          calloc.free(nativeInput);
          calloc.free(nativeOutput);
          calloc.free(errorBuffer);
        }
      });
    } finally {
      // Safe even with progress messages still in flight: already-posted
      // messages are dropped or delivered before close takes effect, and the
      // decoder layer suppresses anything arriving after completion.
      callable.close();
    }
  }
}
