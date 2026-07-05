import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web plugin registrant.
///
/// The web implementation needs no platform channels (decoding runs in a
/// Web Worker created directly from Dart), but Flutter requires a plugin
/// class with a `registerWith` to declare web support in pubspec.yaml.
class FlutterTinyWavpackDecoderWeb {
  /// Called by the generated plugin registrant; nothing to set up.
  static void registerWith(Registrar registrar) {}
}
