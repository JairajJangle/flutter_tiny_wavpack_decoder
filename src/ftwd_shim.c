#include "ftwd_shim.h"

#include <string.h>

#include "tiny-wavpack/common/TinyWavPackDecoderInterface.h"

FFI_PLUGIN_EXPORT int ftwd_decode(
    const char *input_path,
    const char *output_path,
    int max_samples,
    int force_bps,
    FtwdProgressCallback progress_callback,
    void *context,
    char *error_out) {
  /* FtwdProgressCallback and ProgressCallback have identical signatures;
   * the shim re-declares the type so bindings never include the vendored
   * headers. */
  DecoderResult result = decode_wavpack_to_wav(
      input_path, output_path, max_samples, force_bps,
      (ProgressCallback)progress_callback, context);

  if (error_out != NULL) {
    strncpy(error_out, result.error, FTWD_ERROR_BUFFER_SIZE - 1);
    error_out[FTWD_ERROR_BUFFER_SIZE - 1] = '\0';
  }

  return result.success;
}
