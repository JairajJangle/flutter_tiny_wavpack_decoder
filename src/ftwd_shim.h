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

#ifdef __cplusplus
}
#endif

#endif /* FTWD_SHIM_H */
