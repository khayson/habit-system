import 'app_database.dart';

/// The reward numbers exactly as `reward_state` last confirmed them (A39, A44). Nothing here
/// computes XP, a level or a refill date (invariant 9): a missing row, or one without xp or
/// level, reads as null and the screens show no reward line.
class ConfirmedRewardNumbers {
  final int xp;
  final int level;
  final int? progressIntoLevel;
  final int? nextLevelThreshold;
  final int? freezeBalance;

  const ConfirmedRewardNumbers({
    required this.xp,
    required this.level,
    this.progressIntoLevel,
    this.nextLevelThreshold,
    this.freezeBalance,
  });
}

/// Pure Dart (A23): reads the local copy only.
class RewardsView {
  final AppDatabase db;

  const RewardsView(this.db);

  Stream<ConfirmedRewardNumbers?> watch() =>
      db.select(db.rewardState).watch().map((rows) => _numbers(rows.firstOrNull));

  Future<ConfirmedRewardNumbers?> load() async =>
      _numbers(await db.select(db.rewardState).get().then((rows) => rows.firstOrNull));

  static ConfirmedRewardNumbers? _numbers(ConfirmedRewards? row) {
    final xp = row?.xp;
    final level = row?.level;
    if (row == null || xp == null || level == null) return null;
    return ConfirmedRewardNumbers(
      xp: xp,
      level: level,
      progressIntoLevel: row.progressIntoLevel,
      nextLevelThreshold: row.nextLevelThreshold,
      freezeBalance: row.freezeBalance,
    );
  }
}
