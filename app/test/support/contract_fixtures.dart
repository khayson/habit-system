import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Reads golden JSON from the repo-level contract-fixtures/ directory (shared with PHP).
/// `flutter test` runs with the app/ directory as the working directory.
Directory contractFixturesDir() =>
    Directory(p.normalize(p.join(Directory.current.path, '..', 'contract-fixtures')));

Map<String, dynamic> contractFixture(String relative) {
  final file = File(p.join(contractFixturesDir().path, relative));
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<String> contractFixtureNames(String folder) {
  final dir = Directory(p.join(contractFixturesDir().path, folder));
  return dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .map((f) => p.basenameWithoutExtension(f.path))
      .toList()
    ..sort();
}

/// Replaces fixture placeholders with concrete, format-valid values.
Object? materialize(Object? value) {
  return switch (value) {
    '{{uuid}}' => '0199b2c4-1a2b-7c3d-8e4f-5a6b7c8d9e0f',
    '{{timestamp}}' => '2026-05-28T17:22:00Z',
    '{{int}}' => '30',
    '{{cursor}}' => 'eyJ2IjoxfQ.c2lnbmF0dXJl',
    '{{seq}}' => 6,
    final Map<String, dynamic> map => map.map((k, v) => MapEntry(k, materialize(v))),
    final List<dynamic> list => list.map(materialize).toList(),
    _ => value,
  };
}

/// [expected] with placeholders matched by format ({{uuid}}, {{timestamp}}), the rest exactly.
void expectContract(Object? expected, Object? actual, [String path = r'$']) {
  switch (expected) {
    case '{{uuid}}':
      expect(
        actual,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
        reason: path,
      );
    case '{{seq}}':
      expect(actual, isA<int>(), reason: path);
    case '{{timestamp}}':
      expect(
        actual,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$')),
        reason: path,
      );
    case final Map<String, dynamic> map:
      expect(actual, isA<Map<dynamic, dynamic>>(), reason: path);
      expect((actual! as Map).keys.toSet(), map.keys.toSet(), reason: '$path keys');
      for (final e in map.entries) {
        expectContract(e.value, (actual as Map)[e.key], '$path.${e.key}');
      }
    default:
      expect(actual, expected, reason: path);
  }
}
