// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_tiny_wavpack_decoder",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        // Dynamic on purpose: Dart looks the C symbols up at runtime with
        // dlsym. Statically linked into the app, they are removed by the
        // default "Strip Style: All Symbols" of archived release builds, so
        // the lookup would fail in App Store builds. As its own framework the
        // library keeps its exports, mirroring the CocoaPods use_frameworks!
        // layout (see lib/src/library_loader.dart).
        .library(name: "flutter-tiny-wavpack-decoder", type: .dynamic, targets: ["flutter_tiny_wavpack_decoder"])
    ],
    // No FlutterFramework dependency: this is a pure C FFI plugin that never
    // includes Flutter headers, and that package only exists on Flutter
    // 3.44+, so declaring it would break SwiftPM builds on older SDKs.
    dependencies: [],
    targets: [
        // The sources are forwarders that compile the shared decoder in
        // ../../src, which CMake also builds on the other native platforms.
        .target(
            name: "flutter_tiny_wavpack_decoder",
            dependencies: [],
            exclude: ["private_include"],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ],
            cSettings: [
                .headerSearchPath("private_include")
            ]
        )
    ]
)
