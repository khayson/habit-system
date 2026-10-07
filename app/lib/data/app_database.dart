import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// The per-account local working copy. Schema v1 is intentionally empty: habits, logs,
/// outbox and sync_state tables arrive in Phase 2.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
