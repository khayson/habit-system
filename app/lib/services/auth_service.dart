import 'package:uuid/uuid.dart';

import '../core/exceptions/app_exception.dart';
import '../core/network/api_client.dart';
import '../core/storage/account_store.dart';
import '../core/storage/token_store.dart';
import '../data/app_database.dart';
import '../data/database_opener.dart';
import '../sync/sync_engine.dart';

/// A signed-in account and its own database (one file per user id).
class AccountSession {
  final String userId;
  final String deviceId;
  final AppDatabase db;

  /// True when this device had no data for the account before this sign-in (design flow: 02
  /// goes to 04 on first setup).
  final bool firstOnDevice;

  const AccountSession({
    required this.userId,
    required this.deviceId,
    required this.db,
    this.firstOnDevice = false,
  });
}

enum RefreshResult {
  /// A new token is stored.
  refreshed,

  /// The server refused (401): the session is over.
  rejected,

  /// No answer. The old token stays usable for the grace window (A29); try again later.
  unavailable,
}

/// Register, log in, refresh and log out (spec 05, A6, A29).
///
/// Logging out only forgets the token and which account is current. The account's database
/// and its outbox stay on disk for when the same owner signs in again (invariant 8).
class AuthService {
  final ApiClient _api;
  final TokenStore _tokens;
  final AccountStore _accounts;
  final AppDatabase Function(String userId) _openDatabase;
  final DateTime Function() _clock;
  final String _deviceName;

  AuthService(
    this._api,
    this._tokens,
    this._accounts, {
    this._openDatabase = openAccountDatabase,
    DateTime Function()? clock,
    this._deviceName = 'Habit app',
  }) : _clock = clock ?? DateTime.now;

  /// A6: refresh opportunistically once the token is this old (it lives 120 days).
  static const refreshAfter = Duration(days: 30);

  /// The open account database. It stays open after a logout (the engine that triggered the
  /// logout may still be finishing on it) and is closed when another account opens or on
  /// [signOut].
  AccountSession? _opened;
  var _signedIn = false;

  /// The signed-in account, or null.
  AccountSession? get current => _signedIn ? _opened : null;

  Future<AccountSession> register({
    required String name,
    required String email,
    required String password,
    required String timezone,
  }) async {
    final deviceId = await _deviceId();
    final response = await _api.post(
      '/auth/register',
      _session,
      data: {
        'name': name,
        'email': email,
        'password': password,
        'timezone': timezone,
        'device_name': _deviceName,
        'device_id': deviceId,
      },
    );
    return _signIn(response.data, deviceId);
  }

  Future<AccountSession> login({required String email, required String password}) async {
    final deviceId = await _deviceId();
    final response = await _api.post(
      '/auth/login',
      _session,
      data: {
        'email': email,
        'password': password,
        'device_name': _deviceName,
        'device_id': deviceId,
      },
    );
    return _signIn(response.data, deviceId);
  }

  /// Reopens the stored account at start-up, without a network call. Null when signed out.
  Future<AccountSession?> restore() async {
    final userId = await _accounts.readUserId();
    if (userId == null || await _tokens.read() == null) return null;
    return _open(userId, await _deviceId());
  }

  Future<RefreshResult>? _refreshing;

  /// One rotation (A6), single-flight (F5): with one token per device, two overlapping
  /// refreshes would mint two tokens and the server deletes the first, so concurrent callers
  /// share one request. The server keeps the old token valid for a 10-minute grace window
  /// (A29), so a lost response or a network failure keeps the stored token and is retried
  /// later. Only a 401 means the session is over; the [ApiClient] has then cleared the token.
  /// Foreground only: background isolates never refresh (two rotations would leave one of them
  /// holding a deleted token).
  Future<RefreshResult> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<RefreshResult> _refresh() async {
    if (await _tokens.read() == null) return RefreshResult.rejected;
    try {
      final response = await _api.post('/auth/refresh', (d) => (d as Map)['token'] as String);
      await _tokens.write(response.data);
      await _accounts.writeTokenIssuedAt(_clock());
      return RefreshResult.refreshed;
    } on AppException catch (e) {
      return e.isUnauthenticated ? RefreshResult.rejected : RefreshResult.unavailable;
    }
  }

  /// Refreshes when the token is older than [refreshAfter]. Call when online.
  Future<void> refreshIfStale() async {
    final issued = await _accounts.readTokenIssuedAt();
    if (issued != null && _clock().difference(issued) < refreshAfter) return;
    await refresh();
  }

  /// Told once when a session ends, whoever ended it (G1), so the UI never stays on a signed-in
  /// screen while signed out.
  void Function()? onSessionEnded;

  /// Ends the session locally. The database file and its outbox stay on disk.
  Future<void> logout() async {
    final wasSignedIn = _signedIn;
    _signedIn = false;
    await _tokens.clear();
    await _accounts.clearSession();
    if (wasSignedIn) onSessionEnded?.call();
  }

  /// User-initiated sign-out: revoke this device's token (best effort), then [logout].
  Future<void> signOut() async {
    try {
      await _api.post('/auth/logout', (_) => null);
    } on AppException {
      // Offline or already revoked: the local session ends either way.
    }
    await logout();
    final open = _opened;
    _opened = null;
    await open?.db.close();
  }

  Future<AccountSession> _signIn(_Session session, String deviceId) async {
    await _tokens.write(session.token);
    await _accounts.writeSession(userId: session.userId, tokenIssuedAt: _clock());
    final opened = await _open(session.userId, deviceId);
    final known = await opened.db.select(opened.db.syncState).getSingleOrNull();
    final account = AccountSession(
      userId: opened.userId,
      deviceId: opened.deviceId,
      db: opened.db,
      firstOnDevice: known == null,
    );
    await initAccountState(
      account.db,
      userId: session.userId,
      deviceId: deviceId,
      user: session.user,
    );
    return account;
  }

  /// Switching accounts closes (never deletes) the previous account's database.
  Future<AccountSession> _open(String userId, String deviceId) async {
    _signedIn = true;
    final existing = _opened;
    if (existing != null && existing.userId == userId) return existing;
    _opened = null;
    await existing?.db.close();
    return _opened = AccountSession(userId: userId, deviceId: deviceId, db: _openDatabase(userId));
  }

  Future<String> _deviceId() => _accounts.deviceId(() => const Uuid().v7());

  static _Session _session(dynamic data) {
    final map = (data as Map).cast<String, dynamic>();
    final user = (map['user'] as Map).cast<String, dynamic>();
    return _Session(map['token'] as String, user['id'] as String, user);
  }
}

class _Session {
  final String token;
  final String userId;
  final Map<String, dynamic> user;

  const _Session(this.token, this.userId, this.user);
}
