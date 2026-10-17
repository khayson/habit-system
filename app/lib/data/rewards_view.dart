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

/// Screens 16 and 35's level bar and label (A44): display arithmetic on the confirmed numbers,
/// not a rule. span = next_level_threshold - (xp - progress_into_level).
class LevelProgress {
  final int into;
  final int span;
  final int nextLevel;

  const LevelProgress({required this.into, required this.span, required this.nextLevel});

  /// Null when reward_state did not carry the bar's numbers.
  static LevelProgress? of(ConfirmedRewardNumbers rewards) {
    final into = rewards.progressIntoLevel;
    final threshold = rewards.nextLevelThreshold;
    if (into == null || threshold == null) return null;
    return LevelProgress(
      into: into,
      span: threshold - (rewards.xp - into),
      nextLevel: rewards.level + 1,
    );
  }

  /// 0..1; empty when the span is 0 or less.
  double get fraction => span <= 0 ? 0 : (into / span).clamp(0.0, 1.0).toDouble();
}
