import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import 'account_context.dart';

/// The calm line sign in (02) shows after something ended the session on purpose.
enum SignInNotice {
  /// A49: this device deleted the account.
  accountDeleted,

  /// A50: the password was reset; sign in with the new one.
  passwordChanged,
}

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
  SignInNotice? _notice;
  String? _noticeEmail;

  /// What sign in says (A49, A50), until the next sign-in or registration.
  SignInNotice? get signInNotice => _notice;

  /// The email sign in starts with after a reset (A50).
  String? get signInEmail => _noticeEmail;

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

  /// Logout ends this account's reminders and background sync first (Phase 3.2b), but a failure
  /// there never keeps the user signed in (K3): the sign-out always happens. The database stays
  /// on the device.
  Future<void> signOut() async {
    try {
      await _account?.endForLogout();
    } on Object {
      // Best effort: the session must end even if the platform could not cancel.
    }
    await _auth.signOut();
  }

  /// A49: deletes the account on the server (the password is the reauthentication), then this
  /// account's reminders, background sync, database, files and tokens on this device. A failure
  /// on the server (wrong password, offline) throws before anything local changes. Other
  /// accounts on the device are untouched.
  Future<void> deleteAccount(String password) async {
    final account = _account;
    if (account == null) return;
    final receipt = await _auth.requestAccountDeletion(password);
    // Set at once: the 202 revoked this device's token too, so an in-flight sync's 401 may end
    // the session before the steps below.
    _notice = SignInNotice.accountDeleted;
    _noticeEmail = null;
    try {
      await account.endForLogout();
    } on Object {
      // Best effort, as at sign-out: the account is gone on the server either way.
    }
    await _auth.forgetDeletedAccount(receipt);
    try {
      Directory(account.filesRoot).deleteSync(recursive: true);
    } on FileSystemException {
      // No photo folder, or the OS holds it; nothing else reads it now.
    }
    notifyListeners();
  }

  /// A50: asks for a reset code; the same answer for every email. Needs no session.
  Future<void> requestPasswordReset(String email) => _auth.requestPasswordReset(email);

  /// A50: sets the new password with the code, then sign in starts with [email] and a calm
  /// line. The server revoked every session; a signed-in device signs out at its next 401.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
    required String confirmation,
  }) async {
    await _auth.resetPassword(
      email: email,
      code: code,
      password: password,
      confirmation: confirmation,
    );
    _notice = SignInNotice.passwordChanged;
    _noticeEmail = email;
    notifyListeners();
  }

  /// The ApiClient saw the server reject the stored token (it owns that decision, G1).
  Future<void> handleUnauthenticated() => _auth.logout();

  /// The single place a session ends in the UI: user sign-out and a rejected token alike.
  void _ended() => _close();

  void _open(AccountSession session) {
    _notice = null;
    _noticeEmail = null;
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
