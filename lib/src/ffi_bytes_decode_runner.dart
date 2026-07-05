import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'bytes_decode_runner.dart';
import 'library_loader.dart';

/// [BytesDecodeRunner] backed by the bundled C decoder over `dart:ffi`.
///
/// Same isolate/callback architecture as `FfiDecodeRunner` (see its docs):
/// the blocking `ftwd_decode_buffer` call runs in a short-lived worker
/// isolate, and progress flows back through a [NativeCallable.listener]
/// created on the calling isolate.
final class FfiBytesDecodeRunner implements BytesDecodeRunner {
  /// Creates the FFI-backed runner.
  const FfiBytesDecodeRunner();

  @override
  Future<BytesDecodeResult> run(
    BytesDecodeRequest request,
    void Function(double progress) onProgress,
  ) async {
    final callable = NativeCallable<FtwdProgressCallbackNative>.listener(
      (double progress, Pointer<Void> context) => onProgress(progress),
    );
    try {
      // As in FfiDecodeRunner, the worker closure MUST be constructed in
      // _workerBody so its capture context stays sendable.
      return await Isolate.run(
        _workerBody(
          callbackAddress: callable.nativeFunction.address,
          overridePath: ftwdLibraryOverridePath,
          request: request,
        ),
      );
    } finally {
      callable.close();
    }
  }

  /// Builds the worker-isolate entry closure in a scope whose captured
  /// context contains only sendable values (ints, strings, [request]).
  static BytesDecodeResult Function() _workerBody({
    required int callbackAddress,
    required String? overridePath,
    required BytesDecodeRequest request,
  }) {
    return () {
      // Globals are per-isolate; propagate the test override.
      ftwdLibraryOverridePath = overridePath;
      final bindings = FtwdBindings(openFtwdLibrary());

      final input = request.input;
      final nativeInput = calloc<Uint8>(input.length);
      final outputPtr = calloc<Pointer<Uint8>>();
      final outputLen = calloc<Int>();
      final errorBuffer = calloc<Char>(ftwdErrorBufferSize);
      try {
        nativeInput.asTypedList(input.length).setAll(0, input);
        final status = bindings.decodeBuffer(
          nativeInput,
          input.length,
          request.maxSamples,
          request.bitsPerSample,
          Pointer.fromAddress(callbackAddress),
          nullptr,
          outputPtr,
          outputLen,
          errorBuffer,
        );
        if (status != 1) {
          return BytesDecodeResult.failure(
            errorBuffer.cast<Utf8>().toDartString(),
          );
        }
        final wavPtr = outputPtr.value;
        // Copy out of native memory before freeing it.
        final wav = Uint8List.fromList(wavPtr.asTypedList(outputLen.value));
        bindings.freeBuffer(wavPtr);
        return BytesDecodeResult.success(wav);
      } finally {
        calloc.free(nativeInput);
        calloc.free(outputPtr);
        calloc.free(outputLen);
        calloc.free(errorBuffer);
      }
    };
  }
}
