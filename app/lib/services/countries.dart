import 'dart:convert';

import 'package:flutter/services.dart';

/// A20: the country picker's list, assets/countries.json (scripts/gen-countries.php writes it
/// byte for byte equal to the server's copy). Loaded once.
class Country {
  final String code;
  final String name;

  const Country(this.code, this.name);
}

class Countries {
  final List<Country> all;

  const Countries(this.all);

  static Future<Countries>? _loaded;

  static Future<Countries> load([AssetBundle? bundle]) => _loaded ??= () async {
    final json = await (bundle ?? rootBundle).loadString('assets/countries.json');
    final rows = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    return Countries([for (final r in rows) Country(r['code'] as String, r['name'] as String)]);
  }();

  String? nameOf(String? code) {
    if (code == null) return null;
    for (final c in all) {
      if (c.code == code) return c.name;
    }
    return null;
  }

  /// Countries whose name or code contains [query], case-insensitively, in list order.
  List<Country> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final c in all)
        if (c.name.toLowerCase().contains(q) || c.code.toLowerCase() == q) c,
    ];
  }
}
