// Hand-written FFI bindings for src/ftwd_shim.h.
// KEEP IN LOCKSTEP with that header — it is the single native entry point.
import 'dart:ffi';

/// Size of the caller-allocated error buffer, including the trailing NUL.
/// Must match FTWD_ERROR_BUFFER_SIZE in src/ftwd_shim.h.
const int ftwdErrorBufferSize = 80;

/// Native signature of the progress callback
/// (`void (*)(float progress, void *context)`).
typedef FtwdProgressCallbackNative = Void Function(Float, Pointer<Void>);

typedef _FtwdDecodeNative =
    Int Function(
      Pointer<Char> inputPath,
      Pointer<Char> outputPath,
      Int maxSamples,
      Int forceBps,
      Pointer<NativeFunction<FtwdProgressCallbackNative>> progressCallback,
      Pointer<Void> context,
      Pointer<Char> errorOut,
    );

/// Dart signature of `ftwd_decode`. Returns 1 on success, 0 on failure.
typedef FtwdDecodeDart =
    int Function(
      Pointer<Char> inputPath,
      Pointer<Char> outputPath,
      int maxSamples,
      int forceBps,
      Pointer<NativeFunction<FtwdProgressCallbackNative>> progressCallback,
      Pointer<Void> context,
      Pointer<Char> errorOut,
    );

/// Resolved symbols of the native decoder library.
class FtwdBindings {
  /// Looks up the decoder entry point in [library].
  FtwdBindings(DynamicLibrary library)
    : decode = library.lookupFunction<_FtwdDecodeNative, FtwdDecodeDart>(
        'ftwd_decode',
      );

  /// The `ftwd_decode` entry point.
  final FtwdDecodeDart decode;
}
