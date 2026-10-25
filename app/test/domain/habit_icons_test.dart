import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/domain/habit_icon_keys.g.dart';
import 'package:habit/widgets/habit_icon_glyphs.g.dart';
import 'package:habit/domain/habit_icons.dart';
import 'package:habit/widgets/app_icons.dart';
import 'package:hugeicons/hugeicons.dart';

import '../support/contract_fixtures.dart';

/// A53: the habit icon catalog. Generated from the hugeicons package and icons.json; both
/// suites read the same fixture.
void main() {
  final fixture = contractFixture('habit/icons.json');

  group('the generated catalog matches its sources', () {
    test('category defaults, keyword table and featured icons equal icons.json', () {
      expect(
        habitIconCategoryDefaults,
        (fixture['category_defaults'] as Map).cast<String, String>(),
      );
      expect([
        for (final (prefixes, icon) in habitIconKeywords) {'prefixes': prefixes, 'icon': icon},
      ], fixture['keywords']);
      expect([
        for (final (key, label) in habitIconFeatured) {'key': key, 'label': label},
      ], fixture['featured']);
    });

    test('every free stroke-rounded glyph of the installed hugeicons is in it, by kebab key', () {
      final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map;
      final entry = (config['packages'] as List).cast<Map<String, dynamic>>().firstWhere(
        (p) => p['name'] == 'hugeicons',
      );
      final uri = Uri.parse('${entry['rootUri']}/');
      final root = uri.isAbsolute
          ? uri
          : Directory.current.uri.resolve('.dart_tool/').resolveUri(uri);
      final source = File.fromUri(root.resolve('lib/styles/stroke_rounded.dart'))
          .readAsStringSync();
      final count = RegExp(
        r'^  static const List<List<dynamic>> strokeRounded',
        multiLine: true,
      ).allMatches(source).length;
      expect(habitIconGlyphs, hasLength(count));
      expect(
        habitIconKeys,
        habitIconGlyphs.keys.toList(),
        reason: 'the pure key list is the glyph map\'s',
      );
      expect(habitIconGlyphs['book-02'], same(HugeIcons.strokeRoundedBook02));
      expect(habitIconGlyphs['book-open-01'], same(HugeIcons.strokeRoundedBookOpen01));
      expect(habitIconGlyphs['1st-bracket'], same(HugeIcons.strokeRounded1stBracket));
      final pattern = RegExp(fixture['key_pattern'] as String);
      for (final key in habitIconGlyphs.keys) {
        expect(
          pattern.hasMatch(key) && key.length <= (fixture['max_length'] as int),
          isTrue,
          reason: key,
        );
      }
      for (final key in fixture['valid_keys'] as List) {
        expect(habitIconGlyphs.containsKey(key), isTrue, reason: '$key');
      }
    });
  });

  test('suggests from the name as icons.json says', () {
    for (final e in (fixture['suggest_examples'] as List).cast<Map<String, dynamic>>()) {
      expect(HabitIconCatalog.suggest(e['name'] as String), e['icon'], reason: '${e['name']}');
    }
  });

  test('a null or unknown key shows the category default; an unknown category, other', () {
    expect(HabitIconCatalog.keyFor(null, 'learning'), 'book-02');
    expect(HabitIconCatalog.keyFor('book-open-01', 'health'), 'book-open-01');
    expect(HabitIconCatalog.keyFor('icon-from-a-newer-app', 'mindfulness'), 'yoga-03');
    expect(HabitIconCatalog.keyFor(null, 'gardening'), 'star');
    expect(HabitIconCatalog.keyFor(null, null), 'star');
    expect(
      AppIcons.habit('icon-from-a-newer-app', category: 'learning'),
      same(habitIconGlyphs['book-02']),
    );
  });

  test('labels: the featured label, or the words of the key', () {
    expect(HabitIconCatalog.label('book-open-01'), 'Reading');
    expect(HabitIconCatalog.label('coffee-beans'), 'Coffee beans');
    expect(HabitIconCatalog.label('music-note-02'), 'Music note 2');
    expect(HabitIconCatalog.label('3-d-view'), '3 d view');
  });

  group('search', () {
    test('an empty query lists every icon, the featured ones first', () {
      final all = HabitIconCatalog.search('');
      expect(all, hasLength(habitIconGlyphs.length));
      expect(all.take(habitIconFeatured.length), [for (final (k, _) in habitIconFeatured) k]);
    });

    test('matches word prefixes of the key, featured first', () {
      final books = HabitIconCatalog.search('book');
      expect(books.take(2), ['book-open-01', 'book-02']);
      expect(books, contains('book-heart'));
      expect(books, isNot(contains('notebook')), reason: 'prefix of a word, not any substring');
      expect(HabitIconCatalog.search('Book OPEN'), containsAll(['book-open-01', 'book-open-02']));
      expect(HabitIconCatalog.search('book open'), isNot(contains('book-02')));
    });

    test('finds icons by their featured label and the keyword table too', () {
      expect(HabitIconCatalog.search('meditate').first, 'yoga-02');
      expect(HabitIconCatalog.search('pray'), contains('hand-prayer'));
      expect(HabitIconCatalog.search('journal').first, 'notebook');
      expect(HabitIconCatalog.search('water').first, 'glass-water');
    });

    test('no match is an empty list', () {
      expect(HabitIconCatalog.search('zzzqqq'), isEmpty);
    });
  });
}
