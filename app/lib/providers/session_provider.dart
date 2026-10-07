import 'package:flutter/foundation.dart';

import '../core/storage/token_store.dart';

/// Whether a bearer token is present. Login, logout and per-account databases arrive in
/// Phase 2; this only drives the router's auth redirect.
class SessionProvider extends ChangeNotifier {
  final TokenStore _tokens;

  SessionProvider(this._tokens);

  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  /// Reads the stored token once at start-up. No artificial delay.
  Future<void> load() async {
    _isAuthenticated = await _tokens.read() != null;
    notifyListeners();
  }

  /// The server rejected the token. Only the token is gone: the account database and its
  /// outbox are kept for when the same owner signs in again.
  void handleUnauthenticated() {
    if (!_isAuthenticated) return;
    _isAuthenticated = false;
    notifyListeners();
  }
}
