#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_tiny_wavpack_decoder.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_tiny_wavpack_decoder'
  s.version          = '1.0.0'
  s.summary          = 'Decode WavPack (.wv) audio to PCM .wav via the WavPack tiny decoder.'
  s.description      = <<-DESC
Flutter FFI plugin bundling the BSD-licensed WavPack 4.40 "tiny decoder"
C library to convert .wv files to PCM .wav files on-device.
                       DESC
  s.homepage         = 'https://github.com/JairajJangle/flutter_tiny_wavpack_decoder'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Jairaj Jangle' => 'reachout.jairaj.jangle@gmail.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains forwarder C files that relatively import
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  # The vendored glue does `#include "wavpack.h"`, which lives in
  # ../src/tiny-wavpack/lib, hence the extra header search path.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../src" "$(PODS_TARGET_SRCROOT)/../src/tiny-wavpack/lib"'
  }
  s.swift_version = '5.0'
end
