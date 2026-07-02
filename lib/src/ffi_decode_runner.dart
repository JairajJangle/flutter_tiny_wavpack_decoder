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
/// invocation is posted to the calling isolate's event loop, which keeps
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
      // The worker closure MUST be constructed in _workerBody, never inline
      // here: closures created in this scope share one capture context with
      // the listener lambda above, which references the caller's onProgress
      // (typically unsendable widget state); inlining the closure makes
      // Isolate.run's spawn message unsendable and throws at runtime.
      return await Isolate.run(
        _workerBody(
          callbackAddress: callable.nativeFunction.address,
          overridePath: ftwdLibraryOverridePath,
          request: request,
        ),
      );
    } finally {
      // Safe even with progress messages still in flight: already-posted
      // messages are dropped or delivered before close takes effect, and the
      // decoder layer suppresses anything arriving after completion.
      callable.close();
    }
  }

  /// Builds the worker-isolate entry closure in a scope whose captured
  /// context contains only sendable values (ints, strings, [request]).
  static NativeDecodeResult Function() _workerBody({
    required int callbackAddress,
    required String? overridePath,
    required NativeDecodeRequest request,
  }) {
    return () {
      // Globals are per-isolate; propagate the test override.
      ftwdLibraryOverridePath = overridePath;
      final bindings = FtwdBindings(openFtwdLibrary());

      final nativeInput = request.inputPath.toNativeUtf8();
      final nativeOutput = request.outputPath.toNativeUtf8();
      final errorBuffer = calloc<Char>(ftwdErrorBufferSize);
      try {
        final status = bindings.decode(
          nativeInput.cast(),
          nativeOutput.cast(),
          request.maxSamples,
          request.bitsPerSample,
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
    };
  }
}
