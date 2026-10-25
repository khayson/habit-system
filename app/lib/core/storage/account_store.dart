import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Which account is signed in, when its token was issued, and this install's device id (A6).
/// Kept beside the token in the platform keystore. Holds no secrets of its own.
abstract interface class AccountStore {
  Future<String?> readUserId();
  Future<DateTime?> readTokenIssuedAt();
  Future<void> writeSession({required String userId, required DateTime tokenIssuedAt});
  Future<void> writeTokenIssuedAt(DateTime at);

  /// Forgets the signed-in account. The device id survives: tokens are bound to it.
  Future<void> clearSession();

  /// Stable per install; created on first use.
  Future<String> deviceId(String Function() create);

  /// A49: deletion id to receipt token, for every account deleted on this device. Device-level:
  /// it outlives the account and [clearSession] keeps it.
  Future<Map<String, String>> readDeletionReceipts();
  Future<void> addDeletionReceipt(String deletionId, String token);
}

class SecureAccountStore implements AccountStore {
  static const _userId = 'account_user_id';
  static const _issuedAt = 'token_issued_at';
  static const _deviceId = 'device_id';
  static const _deletionReceipts = 'account_deletion_receipts';

  final FlutterSecureStorage _storage;

  const SecureAccountStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<String?> readUserId() => _storage.read(key: _userId);

  @override
  Future<DateTime?> readTokenIssuedAt() async =>
      DateTime.tryParse(await _storage.read(key: _issuedAt) ?? '')?.toUtc();

  @override
  Future<void> writeSession({required String userId, required DateTime tokenIssuedAt}) async {
    await _storage.write(key: _userId, value: userId);
    await writeTokenIssuedAt(tokenIssuedAt);
  }

  @override
  Future<void> writeTokenIssuedAt(DateTime at) =>
      _storage.write(key: _issuedAt, value: at.toUtc().toIso8601String());

  @override
  Future<void> clearSession() async {
    await _storage.delete(key: _userId);
    await _storage.delete(key: _issuedAt);
  }

  @override
  Future<String> deviceId(String Function() create) async {
    final existing = await _storage.read(key: _deviceId);
    if (existing != null) return existing;
    final id = create();
    await _storage.write(key: _deviceId, value: id);
    return id;
  }

  @override
  Future<Map<String, String>> readDeletionReceipts() async {
    try {
      final stored = jsonDecode(await _storage.read(key: _deletionReceipts) ?? '{}');
      return (stored as Map).cast<String, String>();
    } on Object {
      return {};
    }
  }

  @override
  Future<void> addDeletionReceipt(String deletionId, String token) async => _storage.write(
    key: _deletionReceipts,
    value: jsonEncode({...await readDeletionReceipts(), deletionId: token}),
  );
}
