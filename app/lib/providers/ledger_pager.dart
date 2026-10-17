import 'package:flutter/foundation.dart';

/// One fetched page: its rows and the cursor of the next page (null on the last).
class LedgerPage<T> {
  final List<T> rows;
  final String? nextCursor;

  const LedgerPage(this.rows, this.nextCursor);
}

/// Screens 16 and 17's history lists: an explicit network action (CLAUDE.md, Flutter rules).
/// The first page loads on open; Show more appends the next one. A failed first page offers
/// Try again; a failed later page keeps the rows already shown. Held in memory only.
class LedgerPager<T> extends ChangeNotifier {
  final Future<LedgerPage<T>> Function(String? cursor) _fetch;

  LedgerPager(this._fetch);

  final List<T> rows = [];
  String? _next;
  bool loading = false;
  bool loadingMore = false;
  bool loaded = false;
  Object? error;
  Object? moreError;
  bool _disposed = false;

  bool get hasMore => loaded && _next != null;

  /// The first page (also Try again).
  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    _notify();
    try {
      final page = await _fetch(null);
      rows
        ..clear()
        ..addAll(page.rows);
      _next = page.nextCursor;
      loaded = true;
    } on Object catch (e) {
      error = e;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// The next page; the rows already shown stay whatever happens.
  Future<void> more() async {
    final cursor = _next;
    if (cursor == null || loadingMore) return;
    loadingMore = true;
    moreError = null;
    _notify();
    try {
      final page = await _fetch(cursor);
      rows.addAll(page.rows);
      _next = page.nextCursor;
    } on Object catch (e) {
      moreError = e;
    } finally {
      loadingMore = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
