import 'dart:typed_data';

/// Result of one example decode flow, shared by the native and web flows.
class DecodeOutcome {
  DecodeOutcome({required this.summary, this.wavBytes, this.wavName});

  /// Human-readable description of where the output went / how big it is.
  final String summary;

  /// The decoded WAV bytes when the flow decoded in memory (web); null when
  /// the flow wrote a file to disk (native).
  final Uint8List? wavBytes;

  /// Suggested file name for [wavBytes].
  final String? wavName;
}
