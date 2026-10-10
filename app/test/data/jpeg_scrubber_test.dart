import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/jpeg_scrubber.dart';
import 'package:habit/data/photo_service.dart';
import 'package:path/path.dart' as p;

import '../support/fake_sync_server.dart';
import '../sync/sync_harness.dart';

/// R4: metadata is dropped from a chosen photo before it is stored on the phone or uploaded.
/// Every input is built here from bytes (no binary fixtures).
void main() {
  setUpAll(Device.loadZones);

  List<int> segment(int marker, List<int> data) => [
    0xFF,
    marker,
    (data.length + 2) >> 8,
    (data.length + 2) & 0xFF,
    ...data,
  ];
  List<int> ascii(String s) => s.codeUnits;

  final app0 = segment(0xE0, [...ascii('JFIF'), 0, 1, 2, 0, 0, 1, 0, 1, 0, 0]);
  final exif = segment(0xE1, [...ascii('Exif'), 0, 0, ...ascii('II*'), 0, ...ascii('GPS 5.6N')]);
  final xmp = segment(0xE1, [...ascii('http://ns.adobe.com/xap/1.0/'), 0, ...ascii('<x/>')]);
  final icc = segment(0xE2, [...ascii('ICC_PROFILE'), 0, 1, 1, 9, 9]);
  final iptc = segment(0xED, [...ascii('Photoshop 3.0'), 0, ...ascii('8BIM caption')]);
  final comment = segment(0xFE, ascii('taken at home'));
  final dqt = segment(0xDB, List.filled(65, 1));
  // SOS header, then entropy-coded data containing FF E1 and FF 00, then EOI.
  final scan = [
    ...segment(0xDA, [1, 1, 0, 0, 63, 0]),
    0x12, 0xFF, 0xE1, 0x00, 0x34, 0xFF, 0x00, 0x56, //
    0xFF, 0xD9,
  ];
  List<int> jpeg(List<List<int>> segments) => [0xFF, 0xD8, for (final s in segments) ...s, ...scan];

  bool contains(List<int> haystack, List<int> needle) {
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length && match; j++) {
        match = haystack[i + j] == needle[j];
      }
      if (match) return true;
    }
    return false;
  }

  test('drops EXIF/GPS and XMP (APP1), IPTC (APP13) and comments; keeps APP0 and ICC', () {
    final input = jpeg([app0, exif, xmp, icc, iptc, comment, dqt]);

    final out = JpegScrubber.scrub(Uint8List.fromList(input));

    expect(out, [0xFF, 0xD8, ...app0, ...icc, ...dqt, ...scan]);
    for (final gone in ['Exif', 'GPS', 'ns.adobe.com', 'Photoshop', 'taken at home']) {
      expect(contains(out, ascii(gone)), isFalse, reason: gone);
    }
    expect(out.length, lessThan(input.length));
  });

  test('copies everything from SOS on byte for byte, FF E1 in the scan included', () {
    final out = JpegScrubber.scrub(Uint8List.fromList(jpeg([exif, dqt])));
    expect(out.sublist(out.length - scan.length), scan);
  });

  test('returns what it cannot read unchanged', () {
    final cases = <String, List<int>>{
      'no APP1': jpeg([app0, dqt]),
      'truncated segment': jpeg([app0, exif]).sublist(0, 30),
      'length past the end': [0xFF, 0xD8, 0xFF, 0xE1, 0xFF, 0xFF, 1, 2, 3],
      'length below 2': [0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x01, 1, 2, 3, 0xFF, 0xD9],
      'not a JPEG': ascii('a plain text file'),
      'garbage between segments': [0xFF, 0xD8, ...app0, 0x00, 0x11, ...exif, ...scan],
      'empty': <int>[],
    };
    for (final MapEntry(key: name, value: bytes) in cases.entries) {
      final out = JpegScrubber.scrub(Uint8List.fromList(bytes));
      expect(out, bytes, reason: name);
      expect(out.length, lessThanOrEqualTo(bytes.length), reason: name);
    }
  });

  test('copies an input over 8 MB unscrubbed', () {
    final big = Uint8List.fromList([
      ...jpeg([exif]),
      ...List.filled(JpegScrubber.maxBytes, 0),
    ]);
    expect(JpegScrubber.scrub(big), same(big));
  });

  test('PhotoService stores the scrubbed photo', () async {
    final phone = await Device(FakeSyncServer()).init();
    final root = Directory.systemTemp.createTempSync('habit_r4_');
    final crop = File(p.join(root.path, 'crop.jpg'))..writeAsBytesSync(jpeg([app0, exif, dqt]));

    await PhotoService(phone.db, filesRoot: root.path, clock: () => phone.now).choose(crop.path);

    final row = (await phone.db.select(phone.db.pendingUploads).get()).single;
    final stored = File(p.join(root.path, row.localPath!)).readAsBytesSync();
    expect(stored, [0xFF, 0xD8, ...app0, ...dqt, ...scan]);
    await phone.db.close();
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a file briefly; the OS cleans temp.
    }
  });
}
