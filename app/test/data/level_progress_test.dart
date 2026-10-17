import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/rewards_view.dart';

/// A44: the level bar is display arithmetic on the confirmed numbers, in one place.
void main() {
  ConfirmedRewardNumbers numbers(int xp, int level, int? into, int? threshold) =>
      ConfirmedRewardNumbers(
        xp: xp,
        level: level,
        progressIntoLevel: into,
        nextLevelThreshold: threshold,
      );

  test('1,250 XP at level 13: 50 of 100 toward level 14', () {
    final p = LevelProgress.of(numbers(1250, 13, 50, 1300))!;
    expect((p.into, p.span, p.nextLevel, p.fraction), (50, 100, 14, 0.5));
  });

  test('the start of a level is empty; the fraction never leaves 0..1', () {
    expect(LevelProgress.of(numbers(100, 2, 0, 200))!.fraction, 0);
    expect(LevelProgress.of(numbers(250, 2, 150, 200))!.fraction, 1, reason: 'clamped');
  });

  test('a span of 0 or less is empty', () {
    final p = LevelProgress.of(numbers(100, 2, 0, 100))!;
    expect((p.span, p.fraction), (0, 0));
  });

  test('without the bar numbers there is no bar', () {
    expect(LevelProgress.of(numbers(10, 1, null, 100)), isNull);
    expect(LevelProgress.of(numbers(10, 1, 10, null)), isNull);
  });
}
