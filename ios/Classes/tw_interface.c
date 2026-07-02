// Forwarder compiling the vendored decode-to-WAV glue. One stub per
// translation unit — the WavPack sources define file-local statics that
// must not be merged into a single unity build.
#include "../../src/tiny-wavpack/common/TinyWavPackDecoderInterface.c"
