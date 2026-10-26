import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/notice.dart';

/// A57: one account's carousel state: the last notices fetched and the cards the person
/// dismissed, kept in a small JSON file in the account's own folder (no schema change; another
/// account never reads it). Notices are fetched at most every [minInterval]; a failed fetch is
/// silent and the cached ones stay.
class NoticeBoard extends ChangeNotifier {
  static const minInterval = Duration(minutes: 15);
  static const fileName = 'carousel.json';

  /// The account's own folder.
  final String folder;

  /// GET /notices; null where there is no server.
  final Future<List<Notice>> Function()? fetch;
  final DateTime Function() _clock;

  NoticeBoard({required this.folder, this.fetch, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  List<Notice> _notices = const [];
  Set<String> _dismissed = const {};
  DateTime? _fetchedAt;
  bool _loaded = false;
  bool _fetching = false;

  /// False until the file has been read: dismissed cards must not flash in first.
  bool get loaded => _loaded;

  /// Notices still live on this device's clock and not dismissed, newest first.
  List<Notice> get visible => [
    for (final n in _notices)
      if (n.liveAt(_clock()) && !_dismissed.contains(n.id)) n,
  ];

  bool isDismissed(String cardId) => _dismissed.contains(cardId);

  File get _file => File('$folder${Platform.pathSeparator}$fileName');

  /// Reads the file (once), then fetches when the last fetch is older than [minInterval].
  Future<void> refresh() async {
    if (!_loaded) await _load();
    final fetch = this.fetch;
    final at = _fetchedAt;
    if (fetch == null || _fetching) return;
    if (at != null && _clock().difference(at) < minInterval) return;
    _fetching = true;
    try {
      _notices = await fetch();
      _fetchedAt = _clock();
      await _save();
      notifyListeners();
    } on Object {
      // Offline or refused: the carousel keeps its cached notices and built-in cards (A57).
    } finally {
      _fetching = false;
    }
  }

  /// Hides a notice or built-in card on this device for this account.
  Future<void> dismiss(String cardId) async {
    _dismissed = {..._dismissed, cardId};
    notifyListeners();
    await _save();
  }

  Future<void> _load() async {
    try {
      final json = jsonDecode(await _file.readAsString());
      if (json is Map) {
        _notices = [
          for (final item in json['notices'] is List ? json['notices'] as List : const [])
            ?Notice.tryParse(item),
        ];
        _dismissed = {
          for (final id in json['dismissed'] is List ? json['dismissed'] as List : const [])
            if (id is String) id,
        };
        final at = json['fetched_at'];
        _fetchedAt = at is String ? DateTime.tryParse(at) : null;
      }
    } on Object {
      // No file yet, or an unreadable one: start empty.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await Directory(folder).create(recursive: true);
      await _file.writeAsString(
        jsonEncode({
          'fetched_at': _fetchedAt?.toUtc().toIso8601String(),
          'notices': [for (final n in _notices) n.toJson()],
          'dismissed': _dismissed.toList(),
        }),
      );
    } on Object {
      // A full disk loses only a dismissal or a cache; nothing else depends on it.
    }
  }
}
