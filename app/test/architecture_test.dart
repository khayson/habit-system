import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Source-level guards for rules the analyzer cannot express.

/// Raw database construction. Only lib/data/database_opener.dart may do this (ADR 0001).
final rawDatabaseOpen = RegExp(r'\bNativeDatabase\b|\bdriftDatabase\s*\(|\bDriftIsolate\b');

Map<String, String> dartSources(String dir) {
  return {
    for (final file in Directory(dir).listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'))
        p.posix.joinAll(p.split(p.relative(file.path))): _stripComments(file.readAsStringSync()),
  };
}

String _stripComments(String source) =>
    source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '').replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  group('database opener guard', () {
    test('self-test: the pattern catches every raw way to open drift', () {
      expect(rawDatabaseOpen.hasMatch('NativeDatabase(File(path))'), isTrue);
      expect(rawDatabaseOpen.hasMatch('NativeDatabase.createInBackground(f)'), isTrue);
      expect(rawDatabaseOpen.hasMatch("driftDatabase (name: 'x')"), isTrue);
      expect(rawDatabaseOpen.hasMatch('DriftIsolate.spawn(open)'), isTrue);
      expect(rawDatabaseOpen.hasMatch('openAccountDatabase(id)'), isFalse);
      expect(_stripComments('// NativeDatabase in a comment'), isNot(contains('NativeDatabase')));
    });

    test('only lib/data/database_opener.dart opens a database', () {
      final offenders = dartSources('lib').entries
          .where((e) => e.key != 'lib/data/database_opener.dart')
          .where((e) => rawDatabaseOpen.hasMatch(e.value))
          .map((e) => e.key)
          .toList();

      expect(offenders, isEmpty);
    });

    test('the opener itself still uses the shared-server path', () {
      final opener = dartSources('lib')['lib/data/database_opener.dart']!;
      expect(opener, contains('shareAcrossIsolates: true'));
    });
  });
}
