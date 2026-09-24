// Relative import to reuse the C sources shared by all target platforms.
// Neither Package.swift nor the podspec can reference paths outside the
// package root, so this forwarder compiles ../../../../src/ftwd_shim.c.
#include "../../../../src/ftwd_shim.c"
