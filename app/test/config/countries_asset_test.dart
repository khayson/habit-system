import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A20: the picker's bundled list equals the canonical contract-fixtures/profile/countries.json
/// byte for byte (scripts/gen-countries.php writes both).
void main() {
  test('assets/countries.json is the canonical country list', () {
    final asset = File('assets/countries.json').readAsBytesSync();
    final canonical = File(
      p.join('..', 'contract-fixtures', 'profile', 'countries.json'),
    ).readAsBytesSync();

    expect(asset, canonical);
  });
}
