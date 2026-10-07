import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Server-confirmed habits: what the server last said, with its version (invariant 9). The
/// pending overlay is derived from the outbox and is never written here. Known fields are
/// columns; fields this app version does not know live in [extra] and are re-emitted untouched
/// (invariant 13). Everything except id and version is nullable so a future payload shape never
/// breaks a pull.
@DataClassName('ConfirmedHabit')
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  TextColumn get type => text().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get category => text().nullable()();

  /// Wire value as JSON (`1`, `"2000.000"`, `600`).
  TextColumn get targetValue => text().nullable()();
  TextColumn get frequencyType => text().nullable()();
  TextColumn get frequencyConfig => text().nullable()();
  TextColumn get startLocalDate => text().nullable()();
  TextColumn get archivedAt => text().nullable()();
  IntColumn get version => integer()();
  IntColumn get definitionVersion => integer().nullable()();
  TextColumn get definitions => text().nullable()();
  TextColumn get activeRanges => text().nullable()();
  TextColumn get extra => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Server-confirmed logs, including tombstones (also for ids this device never saw).
@DataClassName('ConfirmedLog')
class HabitLogs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().nullable()();
  TextColumn get logDate => text().nullable()();

  /// Wire value as JSON.
  TextColumn get value => text().nullable()();
  TextColumn get detail => text().nullable()();
  TextColumn get occurredAt => text().nullable()();
  TextColumn get completedAt => text().nullable()();
  TextColumn get resolvedTimezone => text().nullable()();
  IntColumn get dayStartOffsetMinutes => integer().nullable()();
  IntColumn get definitionVersion => integer().nullable()();
  IntColumn get version => integer()();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get extra => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Entity types this app version does not know, kept opaque from pulls (invariant 13).
class OpaqueEntities extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get version => integer()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();

  @override
  Set<Column> get primaryKey => {entityType, entityId};
}

/// The durable outbox (spec 04, invariant 8). Rows are never deleted while unacknowledged.
/// States: pending, in_flight, acked, waiting, blocked, needs_attention.
@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get mutationId => text().unique()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  IntColumn get baseVersion => integer().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get capturedTimezone => text().nullable()();
  TextColumn get localDateHint => text().nullable()();
  TextColumn get payload => text()();

  /// For log rows: the habit they belong to (dependency and remapping).
  TextColumn get habitId => text().nullable()();
  TextColumn get state => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().nullable()();
  IntColumn get firstFailedAt => integer().nullable()();
  BoolColumn get surfaced => boolean().withDefault(const Constant(false))();
  TextColumn get lastError => text().nullable()();
  IntColumn get ackVersion => integer().nullable()();
  IntColumn get createdAt => integer()();
}

/// One row (id = 1) per account database.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  IntColumn get id => integer()();
  TextColumn get userId => text()();
  TextColumn get deviceId => text()();
  TextColumn get cursor => text().nullable()();
  TextColumn get bootstrapCursor => text().nullable()();

  /// The server's calendar entry: the zone sent as captured_timezone (A5), never the device's.
  TextColumn get calendarTimezone => text().nullable()();
  IntColumn get calendarDayStartOffset => integer().withDefault(const Constant(0))();
  TextColumn get calendarEffectiveAt => text().nullable()();
  TextColumn get capabilities => text().nullable()();
  TextColumn get userPayload => text().nullable()();
  TextColumn get leaseOwner => text().nullable()();
  IntColumn get leaseUntil => integer().nullable()();
  IntColumn get nextSyncAt => integer().nullable()();
  IntColumn get lastSyncedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The per-account local working copy (one file per user id, see database_opener.dart).
@DriftDatabase(tables: [Habits, HabitLogs, OpaqueEntities, Outbox, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (m, from, to) async {
      // v1 was empty (Phase 0); v2 adds every table.
      if (from < 2) {
        await m.createAll();
        await _createIndexes();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS habit_logs_habit_date ON habit_logs (habit_id, log_date)',
    );
    await customStatement('CREATE INDEX IF NOT EXISTS outbox_state ON outbox (state, seq)');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS outbox_habit_date ON outbox (habit_id, local_date_hint)',
    );
  }
}
