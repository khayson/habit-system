import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import 'account_context.dart';

/// The signed-in account (if any) and where the onboarding flow stands. Drives the router.
///
/// Signing out, or the server rejecting the token, only ends the session: the account's
/// database and its outbox stay on disk for when the same owner signs in again.
class SessionProvider extends ChangeNotifier {
  final AuthService _auth;
  final AccountContext Function(AccountSession session) _buildAccount;

  SessionProvider(this._auth, {required this._buildAccount}) {
    _auth.onSessionEnded = _ended;
  }

  AccountContext? _account;
  bool _needsSetup = false;

  AccountContext? get account => _account;
  bool get isAuthenticated => _account != null;

  /// Screen 04 comes next (after registering, or a first sign-in on this device).
  bool get needsSetup => _needsSetup;

  /// Reopens the stored account at start-up. No network, no artificial delay.
  Future<void> load() async {
    final session = await _auth.restore();
    if (session != null) _open(session);
  }

  Future<void> signIn({required String email, required String password}) async {
    final session = await _auth.login(email: email, password: password);
    _needsSetup = session.firstOnDevice;
    _open(session);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String timezone,
  }) async {
    final session = await _auth.register(
      name: name,
      email: email,
      password: password,
      timezone: timezone,
    );
    _needsSetup = true;
    _open(session);
  }

  void completeSetup() {
    _needsSetup = false;
    notifyListeners();
  }

  Future<void> signOut() => _auth.signOut();

  /// The ApiClient saw the server reject the stored token (it owns that decision, G1).
  Future<void> handleUnauthenticated() => _auth.logout();

  /// The single place a session ends in the UI: user sign-out and a rejected token alike.
  void _ended() => _close();

  void _open(AccountSession session) {
    if (_account?.session.userId != session.userId) {
      _account?.dispose();
      _account = _buildAccount(session);
    }
    notifyListeners();
  }

  void _close() {
    _account?.dispose();
    _account = null;
    _needsSetup = false;
    notifyListeners();
  }
}
