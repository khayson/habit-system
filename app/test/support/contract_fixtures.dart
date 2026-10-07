import 'dart:convert';
import 'dart:io';

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
    final Map<String, dynamic> map => map.map((k, v) => MapEntry(k, materialize(v))),
    final List<dynamic> list => list.map(materialize).toList(),
    _ => value,
  };
}
