import 'dart:async';

import 'package:flutter/foundation.dart';

import '../sync/sync_engine.dart';

/// Sync triggers for one account (Phase 2b.1 review §6): start, resume, after a local write
/// (debounced), connectivity regained, and "Sync now". Every trigger goes through the engine's
/// single-flight run, so overlapping triggers make one request sequence.
///
/// Connectivity is only a trigger, never proof of a connection: [offline] reflects what the
/// last real attempt found.
class SyncProvider extends ChangeNotifier {
  final SyncEngine _engine;
  final Future<void> Function() _refreshIfStale;
  final Duration _debounce;
  StreamSubscription<bool>? _connectivity;
  Timer? _timer;
  bool _disposed = false;

  SyncProvider({
    required this._engine,
    required this._refreshIfStale,
    Stream<bool>? connectivity,
    this._debounce = const Duration(seconds: 2),
  }) {
    _connectivity = connectivity?.listen(_onConnectivity);
  }

  bool _syncing = false;
  SyncOutcome? _lastOutcome;
  bool? _connected;

  bool get syncing => _syncing;
  SyncOutcome? get lastOutcome => _lastOutcome;

  /// The last attempt could not reach the server, or the device reports no network at all.
  bool get offline => _lastOutcome == SyncOutcome.offline || _connected == false;

  /// Runs a sync now. [force] skips the failure backoff (never a 429's Retry-After).
  Future<SyncOutcome> sync({bool force = false}) async {
    _timer?.cancel();
    _set(syncing: true);
    try {
      final outcome = await _engine.run(force: force);
      _lastOutcome = outcome;
      return outcome;
    } finally {
      _set(syncing: false);
    }
  }

  /// After a local write: wait for the burst to settle, then sync once.
  void scheduleAfterWrite() {
    _timer?.cancel();
    _timer = Timer(_debounce, () => sync());
  }

  /// App start and resume (foreground only): refresh an old token while online, then sync.
  Future<void> onForeground() async {
    if (_connected != false) {
      try {
        await _refreshIfStale();
      } on Object {
        // A failed opportunistic refresh is retried next time; the old token still works.
      }
    }
    await sync();
  }

  void _onConnectivity(bool connected) {
    final regained = connected && _connected == false;
    _connected = connected;
    notifyListeners();
    if (regained) sync(force: true);
  }

  void _set({required bool syncing}) {
    if (_disposed) return;
    _syncing = syncing;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _connectivity?.cancel();
    super.dispose();
  }
}
