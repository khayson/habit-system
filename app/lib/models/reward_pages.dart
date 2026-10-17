/// GET /rewards and GET /freezes pages (A39 to A43). Shown from memory only; never written to
/// the local database. Unknown reason and kind words are kept as strings (invariant 13).
library;

class XpLedgerEntry {
  final String id;
  final int delta;

  /// completion, reversal, recompletion, or a word a newer server adds.
  final String reason;
  final String habitId;
  final String logDate;
  final DateTime createdAt;

  const XpLedgerEntry({
    required this.id,
    required this.delta,
    required this.reason,
    required this.habitId,
    required this.logDate,
    required this.createdAt,
  });

  factory XpLedgerEntry.fromJson(Map<String, dynamic> j) => XpLedgerEntry(
    id: j['id'] as String,
    delta: j['delta'] as int,
    reason: j['reason'] as String,
    habitId: j['habit_id'] as String,
    logDate: j['log_date'] as String,
    createdAt: parseInstant(j['created_at']),
  );
}

class RewardsPage {
  final List<XpLedgerEntry> ledger;
  final String? nextCursor;

  const RewardsPage({required this.ledger, required this.nextCursor});

  /// The page's own xp and level are ignored: screens read the local reward_state (A44).
  factory RewardsPage.fromJson(Map<String, dynamic> j) => RewardsPage(
    ledger: [for (final e in j['ledger'] as List) XpLedgerEntry.fromJson((e as Map).cast())],
    nextCursor: j['next_cursor'] as String?,
  );
}

class FreezeLedgerEntry {
  final String id;

  /// grant, spend, refund, or a word a newer server adds.
  final String kind;
  final int delta;
  final String reason;
  final String? habitId;
  final String? periodKey;
  final DateTime createdAt;

  const FreezeLedgerEntry({
    required this.id,
    required this.kind,
    required this.delta,
    required this.reason,
    required this.habitId,
    required this.periodKey,
    required this.createdAt,
  });

  factory FreezeLedgerEntry.fromJson(Map<String, dynamic> j) => FreezeLedgerEntry(
    id: j['id'] as String,
    kind: j['kind'] as String,
    delta: j['delta'] as int,
    reason: j['reason'] as String,
    habitId: j['habit_id'] as String?,
    periodKey: j['period_key'] as String?,
    createdAt: parseInstant(j['created_at']),
  );
}

class FreezesPage {
  final int freezeBalance;
  final int cap;
  final bool autoFreeze;

  /// YYYY-MM-DD exactly as the server sent it; never computed here (A43).
  final String nextRefillOn;
  final List<FreezeLedgerEntry> ledger;
  final String? nextCursor;

  const FreezesPage({
    required this.freezeBalance,
    required this.cap,
    required this.autoFreeze,
    required this.nextRefillOn,
    required this.ledger,
    required this.nextCursor,
  });

  factory FreezesPage.fromJson(Map<String, dynamic> j) => FreezesPage(
    freezeBalance: j['freeze_balance'] as int,
    cap: j['cap'] as int,
    autoFreeze: j['auto_freeze'] as bool,
    nextRefillOn: j['next_refill_on'] as String,
    ledger: [for (final e in j['ledger'] as List) FreezeLedgerEntry.fromJson((e as Map).cast())],
    nextCursor: j['next_cursor'] as String?,
  );
}

/// A wire UTC instant; anything else is a decode error.
DateTime parseInstant(Object? value) {
  final parsed = DateTime.tryParse(value as String);
  if (parsed == null) throw FormatException('Not an instant: $value');
  return parsed.toUtc();
}
