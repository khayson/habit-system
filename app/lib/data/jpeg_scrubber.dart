import 'dart:typed_data';

/// R4: drops photo metadata from a JPEG before it is stored on the phone or uploaded. Pure
/// Dart, bounded, never throws (like the server's JpegOrientation).
///
/// It walks the marker segments from SOI up to SOS and drops APP1 (EXIF, GPS, XMP), APP13
/// (IPTC) and COM; it keeps APP0, APP2 (ICC) and everything else, and copies everything from
/// SOS on byte for byte. Anything it cannot read (not a JPEG, a bad or truncated length,
/// bytes between segments) comes back unchanged, and so does an input over [maxBytes]. The
/// server re-encodes every photo anyway; this keeps the metadata off the phone's copy and the
/// wire.
abstract final class JpegScrubber {
  static const int maxBytes = 8 * 1024 * 1024;
  static const int _maxSegments = 512;
  static const Set<int> _dropped = {0xE1, 0xED, 0xFE};

  static Uint8List scrub(Uint8List input) {
    final n = input.length;
    if (n > maxBytes || n < 4 || input[0] != 0xFF || input[1] != 0xD8) return input;
    final out = BytesBuilder(copy: false)..add(input.sublist(0, 2));
    var pos = 2;
    for (var i = 0; i < _maxSegments; i++) {
      if (pos + 2 > n || input[pos] != 0xFF) return input;
      final marker = input[pos + 1];
      if (marker == 0xDA || marker == 0xD9) {
        // Image data (or the end) from here: copied exactly as it is.
        out.add(input.sublist(pos));
        return out.toBytes();
      }
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        out.add(input.sublist(pos, pos + 2)); // markers without a length
        pos += 2;
        continue;
      }
      if (pos + 4 > n) return input;
      final length = (input[pos + 2] << 8) | input[pos + 3];
      if (length < 2 || pos + 2 + length > n) return input;
      if (!_dropped.contains(marker)) out.add(input.sublist(pos, pos + 2 + length));
      pos += 2 + length;
    }
    return input;
  }
}
