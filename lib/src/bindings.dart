// Hand-written FFI bindings for src/ftwd_shim.h.
// KEEP IN LOCKSTEP with that header; it is the single native entry point.
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

typedef _FtwdDecodeBufferNative =
    Int Function(
      Pointer<Uint8> input,
      Int inputLen,
      Int maxSamples,
      Int forceBps,
      Pointer<NativeFunction<FtwdProgressCallbackNative>> progressCallback,
      Pointer<Void> context,
      Pointer<Pointer<Uint8>> outputOut,
      Pointer<Int> outputLenOut,
      Pointer<Char> errorOut,
    );

/// Dart signature of `ftwd_decode_buffer`. Returns 1 on success, 0 on
/// failure.
typedef FtwdDecodeBufferDart =
    int Function(
      Pointer<Uint8> input,
      int inputLen,
      int maxSamples,
      int forceBps,
      Pointer<NativeFunction<FtwdProgressCallbackNative>> progressCallback,
      Pointer<Void> context,
      Pointer<Pointer<Uint8>> outputOut,
      Pointer<Int> outputLenOut,
      Pointer<Char> errorOut,
    );

typedef _FtwdFreeBufferNative = Void Function(Pointer<Uint8> buffer);

/// Dart signature of `ftwd_free_buffer`.
typedef FtwdFreeBufferDart = void Function(Pointer<Uint8> buffer);

/// Resolved symbols of the native decoder library.
class FtwdBindings {
  /// Looks up the decoder entry points in [library].
  FtwdBindings(DynamicLibrary library)
    : decode = library.lookupFunction<_FtwdDecodeNative, FtwdDecodeDart>(
        'ftwd_decode',
      ),
      decodeBuffer = library
          .lookupFunction<_FtwdDecodeBufferNative, FtwdDecodeBufferDart>(
            'ftwd_decode_buffer',
          ),
      freeBuffer = library
          .lookupFunction<_FtwdFreeBufferNative, FtwdFreeBufferDart>(
            'ftwd_free_buffer',
          );

  /// The `ftwd_decode` entry point.
  final FtwdDecodeDart decode;

  /// The `ftwd_decode_buffer` entry point.
  final FtwdDecodeBufferDart decodeBuffer;

  /// The `ftwd_free_buffer` entry point.
  final FtwdFreeBufferDart freeBuffer;
}
