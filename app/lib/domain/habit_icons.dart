import 'habit_icon_keys.g.dart';

/// A53: a habit's own icon, by key: every free Hugeicons stroke-rounded key, the category
/// defaults, the keyword suggestion and an offline search. Pure Dart (no Flutter), so the forms,
/// background code and the e2e tool share it; the glyphs are AppIcons.habit's.
abstract final class HabitIconCatalog {
  /// The key a habit shows: its own when this app knows it, else its category's default (a
  /// key from a newer app is kept on the habit, never rewritten; invariant 13).
  static String keyFor(String? icon, String? category) {
    if (icon != null && _known.contains(icon)) return icon;
    return habitIconCategoryDefaults[category] ?? habitIconCategoryDefaults['other']!;
  }

  static final Set<String> _known = habitIconKeys.toSet();

  static bool knows(String key) => _known.contains(key);

  /// How many featured icons [search] lists first (the picker's "Suggested").
  static int get featuredCount => habitIconFeatured.length;

  /// The keyword table's icon for [name] (the server's backfill uses the same table), or null.
  static String? suggest(String name) {
    final words = _words(name);
    for (final (prefixes, icon) in habitIconKeywords) {
      if (words.any((w) => prefixes.any(w.startsWith))) return icon;
    }
    return null;
  }

  static final Map<String, String> _featuredLabels = {
    for (final (key, label) in habitIconFeatured) key: label,
  };

  /// The featured label, else the key's words ("music-note-02" reads "Music note 2"). English
  /// only: icon names are not translated (A53).
  static String label(String key) {
    final featured = _featuredLabels[key];
    if (featured != null) return featured;
    final words = key.split('-').map((w) => int.tryParse(w)?.toString() ?? w).join(' ');
    return words.isEmpty ? key : words[0].toUpperCase() + words.substring(1);
  }

  /// Every key whose words (its own, its featured label's and the keyword table's) start with
  /// every word of [query]. The featured icons come first, in their order; then the rest by key.
  static List<String> search(String query) {
    final terms = _words(query);
    bool matches(String key) => terms.every((t) => _index[key]!.any((w) => w.startsWith(t)));
    return [
      for (final key in _ordered)
        if (matches(key)) key,
    ];
  }

  static final List<String> _ordered = [
    for (final (key, _) in habitIconFeatured) key,
    ...(habitIconKeys.where((k) => !_featuredLabels.containsKey(k)).toList()..sort()),
  ];

  static final Map<String, Set<String>> _index = () {
    final index = {for (final key in habitIconKeys) key: key.split('-').toSet()};
    for (final (key, label) in habitIconFeatured) {
      index[key]!.addAll(_words(label));
    }
    for (final (prefixes, icon) in habitIconKeywords) {
      index[icon]!.addAll(prefixes);
    }
    return index;
  }();

  static List<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toList();
}
