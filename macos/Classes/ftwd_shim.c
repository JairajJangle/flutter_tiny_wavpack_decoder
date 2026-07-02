// Relative import to reuse the C sources shared by all target platforms.
// Podspecs cannot reference paths outside the pod root, so this forwarder
// compiles ../../src/ftwd_shim.c (see ../flutter_tiny_wavpack_decoder.podspec).
#include "../../src/ftwd_shim.c"
