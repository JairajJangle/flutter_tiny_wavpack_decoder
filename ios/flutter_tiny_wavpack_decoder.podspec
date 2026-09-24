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

  # DEPRECATED: Swift Package Manager (flutter_tiny_wavpack_decoder/Package.swift)
  # is the supported integration. This podspec is kept only so apps that have
  # not migrated off CocoaPods keep building; it will be removed in a future
  # major release. Both compile the same forwarder C files, which
  # relatively import `../../../../src/*` so that the C sources can be shared
  # among all target platforms. Only the .c files are listed: the headers in
  # that directory exist for SwiftPM and must not become pod public headers.
  s.source           = { :path => '.' }
  s.source_files = 'flutter_tiny_wavpack_decoder/Sources/flutter_tiny_wavpack_decoder/*.c'
  s.resource_bundles = {'flutter_tiny_wavpack_decoder_privacy' => ['flutter_tiny_wavpack_decoder/Sources/flutter_tiny_wavpack_decoder/PrivacyInfo.xcprivacy']}
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  # The vendored glue does `#include "wavpack.h"`, which lives in
  # ../src/tiny-wavpack/lib, hence the extra header search path.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../src" "$(PODS_TARGET_SRCROOT)/../src/tiny-wavpack/lib"'
  }
  s.swift_version = '5.0'
end
