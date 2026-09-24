// Forwarder for the vendored WavPack header. The shared C sources do
// `#include "wavpack.h"` from directories that do not contain it, and
// SwiftPM rejects header search paths outside the package root, so
// Package.swift points its search path here instead. CocoaPods builds use
// the podspec's HEADER_SEARCH_PATHS and never see this file.
#include "../../../../../src/tiny-wavpack/lib/wavpack.h"
