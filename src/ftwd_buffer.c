/* In-memory variant of the decoder entry point: .wv bytes in, a complete
 * WAV file image out. Used by decodeBytes on every platform and it is the
 * only entry point compiled into the web (WASM) build, which has no
 * filesystem. Deliberately independent of TinyWavPackDecoderInterface.c so
 * the WASM build needs no stdio beyond snprintf. */

#include "ftwd_shim.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "tiny-wavpack/common/TinyWavPackDecoderInterface.h" /* WavHeader */
#include "wavpack.h"

/* Cursor over the caller's input bytes for the wavpack read callback. The
 * decoder core keeps static state anyway, so this being static adds no new
 * reentrancy constraint. */
static const unsigned char *g_input = NULL;
static uint32_t g_input_len = 0;
static uint32_t g_input_pos = 0;

static int read_bytes_mem(void *data, int bcount) {
  uint32_t remaining = g_input_len - g_input_pos;
  uint32_t n = (bcount < 0) ? 0
               : ((uint32_t)bcount < remaining ? (uint32_t)bcount : remaining);
  memcpy(data, g_input + g_input_pos, n);
  g_input_pos += n;
  return (int)n;
}

static int fail(char *error_out, const char *message) {
  if (error_out != NULL) {
    strncpy(error_out, message, FTWD_ERROR_BUFFER_SIZE - 1);
    error_out[FTWD_ERROR_BUFFER_SIZE - 1] = '\0';
  }
  return 0;
}

/* Mirrors format_samples in TinyWavPackDecoderInterface.c, which is static
 * there and not compiled into the WASM build. Keep the two in lockstep. */
static void format_samples_mem(int bytes_per_sample, void *dst, int32_t *src,
                               uint32_t samcnt, int is_float,
                               int bits_per_sample) {
  switch (bytes_per_sample) {
    case 1: {
      uint8_t *d = (uint8_t *)dst;
      for (uint32_t i = 0; i < samcnt; i++) {
        if (is_float) {
          float val = *(float *)(&src[i]);
          val = val > 1.0f ? 1.0f : (val < -1.0f ? -1.0f : val);
          d[i] = (uint8_t)((val * 127.0f) + 128);
        } else {
          int32_t val = src[i];
          val = val > 32767 ? 32767 : (val < -32768 ? -32768 : val);
          d[i] = (uint8_t)((val >> (bits_per_sample <= 16 ? 0 : (bits_per_sample - 16))) + 128);
        }
      }
      break;
    }
    case 2: {
      int16_t *d = (int16_t *)dst;
      for (uint32_t i = 0; i < samcnt; i++) {
        if (is_float) {
          float val = *(float *)(&src[i]);
          val = val > 1.0f ? 1.0f : (val < -1.0f ? -1.0f : val);
          d[i] = (int16_t)(val * 32767.0f);
        } else {
          int32_t val = src[i];
          val = val > 32767 ? 32767 : (val < -32768 ? -32768 : val);
          d[i] = (int16_t)(bits_per_sample <= 16 ? val : (val >> (bits_per_sample - 16)));
        }
      }
      break;
    }
    case 3: {
      uint8_t *d = (uint8_t *)dst;
      for (uint32_t i = 0; i < samcnt; i++) {
        int32_t val;
        if (is_float) {
          float fval = *(float *)(&src[i]);
          fval = fval > 1.0f ? 1.0f : (fval < -1.0f ? -1.0f : fval);
          val = (int32_t)(fval * 8388607.0f);
        } else {
          val = src[i];
          val = val > 8388607 ? 8388607 : (val < -8388608 ? -8388608 : val);
        }
        d[i * 3] = (uint8_t)(val);
        d[i * 3 + 1] = (uint8_t)(val >> 8);
        d[i * 3 + 2] = (uint8_t)(val >> 16);
      }
      break;
    }
    case 4: {
      int32_t *d = (int32_t *)dst;
      for (uint32_t i = 0; i < samcnt; i++) {
        if (is_float) {
          float val = *(float *)(&src[i]);
          val = val > 1.0f ? 1.0f : (val < -1.0f ? -1.0f : val);
          d[i] = (int32_t)(val * 2147483647.0f);
        } else {
          d[i] = src[i];
        }
      }
      break;
    }
  }
}

FFI_PLUGIN_EXPORT int ftwd_decode_buffer(
    const unsigned char *input,
    int input_len,
    int max_samples,
    int force_bps,
    FtwdProgressCallback progress_callback,
    void *context,
    unsigned char **output_out,
    int *output_len_out,
    char *error_out) {
  if (output_out != NULL) *output_out = NULL;
  if (output_len_out != NULL) *output_len_out = 0;

  if (input == NULL || input_len <= 0 || output_out == NULL ||
      output_len_out == NULL) {
    return fail(error_out, "Invalid input buffer");
  }
  if (max_samples < -1) {
    return fail(error_out, "Invalid max samples");
  }
  if (force_bps && force_bps != 8 && force_bps != 16 && force_bps != 24 &&
      force_bps != 32) {
    return fail(error_out, "Invalid bits per sample (must be 8, 16, 24, or 32)");
  }

  g_input = input;
  g_input_len = (uint32_t)input_len;
  g_input_pos = 0;

  char wp_error[80];
  WavpackContext *wpc = WavpackOpenFileInput(read_bytes_mem, wp_error);
  if (!wpc) {
    g_input = NULL;
    return fail(error_out, wp_error);
  }

  int numChannels = WavpackGetNumChannels(wpc);
  int sampleRate = WavpackGetSampleRate(wpc);
  int bitsPerSample = WavpackGetBitsPerSample(wpc);
  int numSamples = WavpackGetNumSamples(wpc);
  int isFloatFormat = (WavpackGetMode(wpc) & MODE_FLOAT) != 0;

  if (numChannels <= 0 || numChannels > 100) {
    g_input = NULL;
    return fail(error_out, "Invalid number of channels");
  }
  if (numSamples <= 0) {
    g_input = NULL;
    return fail(error_out, "Invalid number of samples");
  }

  uint32_t samples_to_decode =
      (max_samples == -1)
          ? (uint32_t)numSamples
          : (max_samples > numSamples ? (uint32_t)numSamples
                                      : (uint32_t)max_samples);

  uint32_t bytesPerSample = force_bps ? (uint32_t)(force_bps / 8) : 2;

  if ((uint64_t)samples_to_decode * numChannels * bytesPerSample >
      UINT32_MAX - sizeof(WavHeader)) {
    g_input = NULL;
    return fail(error_out, "Audio data size exceeds 32-bit limit");
  }

  uint32_t dataSize = samples_to_decode * numChannels * bytesPerSample;
  uint32_t totalSize = (uint32_t)sizeof(WavHeader) + dataSize;

  unsigned char *wav = (unsigned char *)malloc(totalSize);
  if (!wav) {
    g_input = NULL;
    return fail(error_out, "Memory allocation failed");
  }

  WavHeader header = {
      .riff = {'R', 'I', 'F', 'F'},
      .fileSize = dataSize + 36,
      .wave = {'W', 'A', 'V', 'E'},
      .fmt = {'f', 'm', 't', ' '},
      .fmtSize = 16,
      .audioFormat = 1,
      .numChannels = (uint16_t)numChannels,
      .sampleRate = (uint32_t)sampleRate,
      .byteRate = (uint32_t)(sampleRate * numChannels * bytesPerSample),
      .blockAlign = (uint16_t)(numChannels * bytesPerSample),
      .bitsPerSample = (uint16_t)(bytesPerSample * 8),
      .data = {'d', 'a', 't', 'a'},
      .dataSize = dataSize};
  memcpy(wav, &header, sizeof(WavHeader));

  const int BUFFER_SIZE = 4096;
  int32_t *buffer = (int32_t *)malloc(BUFFER_SIZE * numChannels * sizeof(int32_t));
  if (!buffer) {
    free(wav);
    g_input = NULL;
    return fail(error_out, "Memory allocation failed");
  }

  uint32_t totalSamplesRead = 0;
  unsigned char *write_cursor = wav + sizeof(WavHeader);

  while (totalSamplesRead < samples_to_decode) {
    uint32_t samplesToRead = samples_to_decode - totalSamplesRead;
    if (samplesToRead > (uint32_t)BUFFER_SIZE) samplesToRead = BUFFER_SIZE;

    int samplesRead = WavpackUnpackSamples(wpc, buffer, samplesToRead);
    if (samplesRead < 0) {
      free(buffer);
      free(wav);
      g_input = NULL;
      return fail(error_out, "Failed to unpack samples");
    }
    if (samplesRead == 0) break;

    format_samples_mem(bytesPerSample, write_cursor, buffer,
                       (uint32_t)samplesRead * numChannels, isFloatFormat,
                       bitsPerSample);
    write_cursor += (uint32_t)samplesRead * numChannels * bytesPerSample;
    totalSamplesRead += (uint32_t)samplesRead;

    if (progress_callback) {
      progress_callback((float)totalSamplesRead / samples_to_decode, context);
    }
  }

  free(buffer);
  g_input = NULL;

  if (WavpackGetNumErrors(wpc) > 0) {
    char err_msg[80];
    snprintf(err_msg, sizeof(err_msg), "Decoding failed with %d CRC errors",
             WavpackGetNumErrors(wpc));
    free(wav);
    return fail(error_out, err_msg);
  }

  if (totalSamplesRead != samples_to_decode) {
    free(wav);
    return fail(error_out, "Failed to decode all requested samples");
  }

  *output_out = wav;
  *output_len_out = (int)totalSize;
  return 1;
}

FFI_PLUGIN_EXPORT void ftwd_free_buffer(unsigned char *buffer) {
  free(buffer);
}
