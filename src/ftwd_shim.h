#ifndef FTWD_SHIM_H
#define FTWD_SHIM_H

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

/* Must match ftwdErrorBufferSize in lib/src/bindings.dart. */
#define FTWD_ERROR_BUFFER_SIZE 80

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*FtwdProgressCallback)(float progress, void *context);

/* Decodes the WavPack file at input_path to a PCM WAV file at output_path.
 *
 * max_samples: -1 decodes everything, otherwise caps samples per channel.
 * force_bps:   0 (defaults to 16), 8, 16, 24, or 32 output bits per sample.
 * progress_callback (nullable) receives values in (0, 1] with the given
 * context pointer, invoked on the decoding thread.
 *
 * Returns 1 on success, 0 on failure. On failure a NUL-terminated message
 * (at most FTWD_ERROR_BUFFER_SIZE bytes including NUL) is written to
 * error_out, which must point to at least FTWD_ERROR_BUFFER_SIZE bytes.
 *
 * NOT reentrant: the underlying decoder keeps static state, so callers must
 * serialize invocations process-wide. */
FFI_PLUGIN_EXPORT int ftwd_decode(
    const char *input_path,
    const char *output_path,
    int max_samples,
    int force_bps,
    FtwdProgressCallback progress_callback,
    void *context,
    char *error_out);

/* Decodes a WavPack stream held in memory to a complete PCM WAV image
 * (44-byte canonical header + data) allocated with malloc.
 *
 * input/input_len describe the .wv bytes. max_samples, force_bps,
 * progress_callback, context and error_out behave exactly as in
 * ftwd_decode.
 *
 * On success returns 1 and stores the malloc'd WAV image in *output_out
 * and its length in *output_len_out; the caller must release it with
 * ftwd_free_buffer. On failure returns 0, writes a message to error_out,
 * and leaves *output_out and *output_len_out zeroed.
 *
 * NOT reentrant: shares the same static decoder state as ftwd_decode, so
 * callers must serialize all decodes process-wide. */
FFI_PLUGIN_EXPORT int ftwd_decode_buffer(
    const unsigned char *input,
    int input_len,
    int max_samples,
    int force_bps,
    FtwdProgressCallback progress_callback,
    void *context,
    unsigned char **output_out,
    int *output_len_out,
    char *error_out);

/* Frees a buffer returned via ftwd_decode_buffer's output_out. */
FFI_PLUGIN_EXPORT void ftwd_free_buffer(unsigned char *buffer);

#ifdef __cplusplus
}
#endif

#endif /* FTWD_SHIM_H */
