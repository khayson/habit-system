import 'app_database.dart';

/// A36: a timer draft as screens read it.
class TimerDraftView {
  static const running = 'running';
  static const paused = 'paused';

  final TimerDraft row;

  const TimerDraftView(this.row);

  String get habitId => row.habitId;
  String get state => row.state;
  int get elapsedMs => row.elapsedMs;
  int? get runningSince => row.runningSince;
  int get createdAt => row.createdAt;

  /// Banked time plus the running span; a clock set backwards adds nothing (never shrinks).
  int elapsedAt(int nowMs) {
    final since = row.runningSince;
    if (row.state != running || since == null) return row.elapsedMs;
    final span = nowMs - since;
    return row.elapsedMs + (span > 0 ? span : 0);
  }

  Duration elapsed(DateTime now) => Duration(milliseconds: elapsedAt(now.millisecondsSinceEpoch));
}
