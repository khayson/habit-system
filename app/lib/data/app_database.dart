import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:sqlite3/common.dart' show SqliteException;

import 'entity_codec.dart';

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

  /// 429: no request before this instant (Retry-After). Nothing bypasses it.
  IntColumn get nextSyncAt => integer().nullable()();
  IntColumn get lastSyncedAt => integer().nullable()();

  /// 5xx, network and whole-request 4xx failures in a row, and the backoff they earned (F6).
  IntColumn get consecutiveFailures => integer().withDefault(const Constant(0))();
  IntColumn get backoffUntil => integer().nullable()();

  /// Whole-request 403/404/422 on /sync in a row; at 3 the status becomes paused (F7).
  IntColumn get requestRejections => integer().withDefault(const Constant(0))();

  /// `active` or `paused`; [statusCode] is the server's error code while paused.
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get statusCode => text().nullable()();

  /// The last failure of a run, as JSON `{code, message}` (F2). Cleared by a completed run.
  TextColumn get lastError => text().nullable()();

  /// Server time minus device time, from `meta.server_time` (F10).
  IntColumn get clockSkewMs => integer().withDefault(const Constant(0))();

  /// The app version that last synced this database; a change replays undecodable items (G5).
  TextColumn get appVersion => text().nullable()();

  /// Phase 3b (A20): the profile photo this device shows, as a path relative to the account's
  /// folder: a photo chosen here (waiting to upload, or uploaded) or a downloaded copy of the
  /// server's. Null shows initials.
  TextColumn get avatarFile => text().nullable()();

  /// The server avatar_version [avatarFile] belongs to; null while a photo chosen here has not
  /// been acknowledged.
  IntColumn get avatarFileVersion => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The account's calendar history from the user entity's `calendar_history` (A26, D1): settled
/// entries and at most one pending change. Merged by effective_at; never a provisional value.
@DataClassName('CalendarEntryRow')
class CalendarEntries extends Table {
  /// UTC milliseconds.
  IntColumn get effectiveAt => integer()();
  TextColumn get timezone => text()();
  IntColumn get dayStartOffsetMinutes => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {effectiveAt};
}

/// A32 `habit_progress`: the server's streak for a habit (id = habit id). Server-confirmed only
/// (invariant 9); unknown fields live in [extra].
@DataClassName('ConfirmedProgress')
class HabitProgress extends Table {
  TextColumn get habitId => text()();
  IntColumn get current => integer().nullable()();
  IntColumn get longest => integer().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get computedThrough => text().nullable()();
  IntColumn get version => integer()();
  TextColumn get extra => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {habitId};
}

/// A32 `period_evaluation`: one closed period's result. Version = revision. Server-confirmed only.
@DataClassName('ConfirmedEvaluation')
class PeriodEvaluations extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().nullable()();
  TextColumn get periodKey => text().nullable()();
  TextColumn get startDate => text().nullable()();
  TextColumn get endDate => text().nullable()();
  BoolColumn get completed => boolean().nullable()();
  BoolColumn get protected => boolean().nullable()();
  IntColumn get definitionVersion => integer().nullable()();
  TextColumn get timezone => text().nullable()();
  IntColumn get revision => integer()();
  TextColumn get extra => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-device settings that are not account data on the server (yet).
@DataClassName('LocalSetting')
class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Phase 3.2b `reminder`: a clock time and ISO days (never a UTC instant), server-confirmed
/// only (invariant 9). Tombstones stay with [deletedAt] set; unknown fields live in [extra].
@DataClassName('ConfirmedReminder')
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text().nullable()();
  TextColumn get localTime => text().nullable()();

  /// JSON array of ISO days, 1 = Monday.
  TextColumn get daysOfWeek => text().nullable()();
  TextColumn get timezoneMode => text().nullable()();
  TextColumn get timezone => text().nullable()();
  BoolColumn get enabled => boolean().nullable()();
  IntColumn get version => integer()();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get extra => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Notifications this account has handed to the OS (Phase 3.2b), so a logout cancels exactly
/// its own and a replan replaces rather than duplicates.
@DataClassName('ScheduledNotification')
class ScheduledNotifications extends Table {
  /// The platform notification id (stable per account + reminder + local date slot).
  IntColumn get platformId => integer()();
  TextColumn get reminderId => text()();
  TextColumn get habitId => text()();

  /// Local date (YYYY-MM-DD) of the slot.
  TextColumn get slotDate => text()();

  /// UTC milliseconds.
  IntColumn get fireAt => integer()();

  @override
  Set<Column> get primaryKey => {platformId};
}

/// Phase 3b (A20): profile photo changes waiting for the server. A photo is binary, so it is not
/// an outbox mutation; the row is the durable queue and its id is the Idempotency-Key. A row is
/// removed only once the server acknowledged it, or when a newer choice replaces it while it is
/// unsent (ASSUMPTION(A3b-upload-supersede)). States: pending, rejected.
@DataClassName('PendingUpload')
class PendingUploads extends Table {
  TextColumn get id => text()();

  /// put or delete.
  TextColumn get op => text()();

  /// For a put: the prepared JPEG, relative to the account's folder.
  TextColumn get localPath => text().nullable()();
  TextColumn get state => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Unacknowledged mutations the user chose to discard (screen 18). Kept as a record; never sent.
class DiscardedMutations extends Table {
  TextColumn get mutationId => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  TextColumn get localDateHint => text().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get discardedAt => integer()();

  @override
  Set<Column> get primaryKey => {mutationId};
}

/// The per-account local working copy (one file per user id, see database_opener.dart).
@DriftDatabase(
  tables: [
    Habits,
    HabitLogs,
    OpaqueEntities,
    Outbox,
    SyncState,
    DiscardedMutations,
    CalendarEntries,
    HabitProgress,
    PeriodEvaluations,
    LocalSettings,
    Reminders,
    ScheduledNotifications,
    PendingUploads,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static final _inTransaction = Object();

  /// Phase 3.2b, K2: two independent connections to one file (background sync in its own
  /// isolate or process) can have SQLite refuse `BEGIN IMMEDIATE` at once with SQLITE_BUSY,
  /// without waiting on busy_timeout (seen in the 2b spike). drift sends BEGIN before it calls
  /// the body, so a refusal arrives before [action] starts: only then is the outermost
  /// transaction run again; nothing was written. A BUSY from inside the body surfaces, and the
  /// body never runs twice. Nested transactions (savepoints) are never retried on their own.
  /// The error is recognised however it crosses the drift isolate (see [isBusy]).
  @override
  Future<T> transaction<T>(Future<T> Function() action, {bool requireNew = false}) async {
    if (Zone.current[_inTransaction] == true) {
      return super.transaction(action, requireNew: requireNew);
    }
    for (var attempt = 1; ; attempt++) {
      var started = false;
      try {
        return await runZoned(
          () => super.transaction(() {
            started = true;
            return action();
          }, requireNew: requireNew),
          zoneValues: {_inTransaction: true},
        );
      } on Object catch (e) {
        if (started || !isBusy(e) || attempt >= busyRetries) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 5 * attempt));
      }
    }
  }

  /// SQLITE_BUSY as each opener delivers it: an in-process SqliteException; through a drift
  /// isolate, a DriftRemoteException carrying that SqliteException when the ports can send
  /// objects (same Flutter engine), or its text when drift serializes (another engine, such as
  /// workmanager's). Pinned by test/data/busy_retry_test.dart.
  static bool isBusy(Object error) => switch (error) {
    SqliteException(:final resultCode) => (resultCode & 0xff) == 5,
    DriftRemoteException(remoteCause: final SqliteException cause) =>
      (cause.resultCode & 0xff) == 5,
    DriftRemoteException(:final remoteCause) => '$remoteCause'.contains('database is locked'),
    _ => false,
  };

  static const busyRetries = 50;

  @override
  int get schemaVersion => 7;

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
        return;
      }
      if (from < 3) {
        // Phase 2b.1 review: sync health, pause, clock skew and the discard record.
        for (final column in [
          syncState.consecutiveFailures,
          syncState.backoffUntil,
          syncState.requestRejections,
          syncState.status,
          syncState.statusCode,
          syncState.lastError,
          syncState.clockSkewMs,
        ]) {
          await m.addColumn(syncState, column);
        }
        await m.createTable(discardedMutations);
      }
      if (from < 4) {
        // Phase 2b.2 review G5.
        await m.addColumn(syncState, syncState.appVersion);
      }
      if (from < 5) {
        // Phase 3.2a: the calendar history, the A32 entities, device settings.
        await m.createTable(calendarEntries);
        await m.createTable(habitProgress);
        await m.createTable(periodEvaluations);
        await m.createTable(localSettings);
        await _createIndexes();
        await _typeOpaqueDerivedEntities();
      }
      if (from < 6) {
        // Phase 3.2b: reminders (typed; a 3.2a build kept them opaque) and the schedule record.
        await m.createTable(reminders);
        await m.createTable(scheduledNotifications);
        await _typeOpaqueReminders();
      }
      if (from < 7) {
        // Phase 3b: the photo this device shows, and the durable photo upload queue.
        await m.addColumn(syncState, syncState.avatarFile);
        await m.addColumn(syncState, syncState.avatarFileVersion);
        await m.createTable(pendingUploads);
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
    await customStatement(
      'CREATE INDEX IF NOT EXISTS period_evaluations_habit_start '
      'ON period_evaluations (habit_id, start_date)',
    );
  }

  /// A 3.2a build kept reminders opaque. Type the ones that decode (version >= rule).
  Future<void> _typeOpaqueReminders() async {
    final rows = await (select(
      opaqueEntities,
    )..where((o) => o.entityType.equals('reminder'))).get();
    for (final row in rows) {
      try {
        final payload = (jsonDecode(row.payload) as Map).cast<String, dynamic>();
        await into(reminders).insertOnConflictUpdate(
          EntityCodec.reminderRow(payload, id: row.entityId, version: row.version),
        );
      } on Object {
        continue; // stays opaque
      }
      await (delete(
        opaqueEntities,
      )..where((o) => o.entityType.equals('reminder') & o.entityId.equals(row.entityId))).go();
    }
  }

  /// A 3.1 build kept A32 entities opaque. Move the ones that decode into the typed tables (the
  /// same version >= rule as a pull); anything that does not decode stays opaque.
  Future<void> _typeOpaqueDerivedEntities() async {
    final rows = await (select(
      opaqueEntities,
    )..where((o) => o.entityType.isIn(['habit_progress', 'period_evaluation']))).get();
    for (final row in rows) {
      try {
        final payload = (jsonDecode(row.payload) as Map).cast<String, dynamic>();
        if (row.entityType == 'habit_progress') {
          await into(habitProgress).insertOnConflictUpdate(
            EntityCodec.progressRow(payload, habitId: row.entityId, version: row.version),
          );
        } else {
          await into(periodEvaluations).insertOnConflictUpdate(
            EntityCodec.evaluationRow(payload, id: row.entityId, version: row.version),
          );
        }
      } on Object {
        continue; // stays opaque
      }
      await (delete(
        opaqueEntities,
      )..where((o) => o.entityType.equals(row.entityType) & o.entityId.equals(row.entityId))).go();
    }
  }
}
