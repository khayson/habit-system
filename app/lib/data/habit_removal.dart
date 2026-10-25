import 'app_database.dart';

/// A51: removes everything this device holds for a deleted habit: the habit, its check-ins, its
/// streak and evaluations, its reminders and any timer draft. The outbox is the caller's business
/// (the deleting device drops the habit's unsent rows; another device keeps them so the server's
/// answer can say what happened). The reminder planner replans from the reminders table, so
/// removing them cancels their notifications. Call inside a transaction.
Future<void> removeHabitLocally(AppDatabase db, String habitId) async {
  await (db.delete(db.habits)..where((h) => h.id.equals(habitId))).go();
  await (db.delete(db.habitLogs)..where((l) => l.habitId.equals(habitId))).go();
  await (db.delete(db.habitProgress)..where((p) => p.habitId.equals(habitId))).go();
  await (db.delete(db.periodEvaluations)..where((e) => e.habitId.equals(habitId))).go();
  await (db.delete(db.reminders)..where((r) => r.habitId.equals(habitId))).go();
  await (db.delete(db.timerDrafts)..where((d) => d.habitId.equals(habitId))).go();
}
