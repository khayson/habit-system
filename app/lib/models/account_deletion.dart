/// A49: an account deletion's status words. Unknown words are kept, never a crash (A21).
enum AccountDeletionStatus {
  queued,
  purging,
  completed,
  unknown;

  static AccountDeletionStatus from(String? word) =>
      values.firstWhere((s) => s.name == word && s != unknown, orElse: () => unknown);
}

/// A49: what GET /account-deletions/{id} returns, and the first four fields of DELETE /me's 202.
class AccountDeletion {
  final String id;
  final AccountDeletionStatus status;
  final DateTime? requestedAt;
  final DateTime? completedAt;

  const AccountDeletion({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.completedAt,
  });

  factory AccountDeletion.fromJson(Map<String, dynamic> json) => AccountDeletion(
    id: json['id'] as String,
    status: AccountDeletionStatus.from(json['status'] as String?),
    requestedAt: DateTime.tryParse(json['requested_at'] as String? ?? '')?.toUtc(),
    completedAt: DateTime.tryParse(json['completed_at'] as String? ?? '')?.toUtc(),
  );
}

/// A49: DELETE /me's 202. [token] is returned once and reads only this deletion's status; the
/// app keeps it under a device-level key because it outlives the account.
class DeletionReceipt {
  final AccountDeletion deletion;
  final String token;
  final DateTime? expiresAt;

  const DeletionReceipt({required this.deletion, required this.token, this.expiresAt});

  factory DeletionReceipt.fromJson(Map<String, dynamic> json) => DeletionReceipt(
    deletion: AccountDeletion.fromJson(json),
    token: json['receipt_token'] as String,
    expiresAt: DateTime.tryParse(json['receipt_expires_at'] as String? ?? '')?.toUtc(),
  );
}
