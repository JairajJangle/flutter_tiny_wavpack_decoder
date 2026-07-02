/// Thrown when a WavPack decode operation fails at runtime.
///
/// Raised for problems that can only be discovered while decoding: a missing
/// or unreadable input file, a stream that is not valid WavPack, CRC errors
/// in the bitstream, an unwritable output path, and similar conditions.
/// Programming errors (such as an invalid `bitsPerSample` value) throw
/// [ArgumentError] instead.
class WavpackDecodeException implements Exception {
  /// Creates an exception carrying the failure [message].
  const WavpackDecodeException(this.message);

  /// Human-readable failure reason.
  ///
  /// Either produced by Dart-side pre-flight checks (for example a missing
  /// input file) or propagated verbatim from the native decoder's error
  /// buffer, e.g. `"Invalid WavPack file"` or
  /// `"Decoding failed with 3 CRC errors"`.
  final String message;

  @override
  String toString() => 'WavpackDecodeException: $message';
}
