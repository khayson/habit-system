import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/calendar/day_resolver.dart';
import '../domain/calendar/local_date.dart';
import '../domain/calendar/timezone_timeline.dart' show DayResolutionException;
import '../domain/habit_draft.dart';
import '../domain/provisional_type_rules.dart';
import '../sync/outbox_states.dart';
import 'account_calendar.dart';
import 'app_database.dart';
import 'entity_codec.dart';
import 'log_overlay.dart';

/// The only way the app writes domain data locally (A23, invariant 16). Pure Dart: no Flutter
/// imports, so the UI, notification actions, widgets and background isolates share it.
///
/// Every write is one drift transaction that appends (or coalesces) an outbox row. The
/// provisional state the UI shows is derived from those rows over the confirmed rows
/// (LocalView), so the projection and the outbox can never disagree (invariant 8), and nothing
/// provisional is ever written into a confirmed row (invariant 9).
class LocalMutationService {
  final AppDatabase db;
  final Clock clock;
  final Uuid _uuid;

  LocalMutationService(this.db, {Clock? clock, Uuid? uuid})
    : clock = clock ?? (() => DateTime.now().toUtc()),
      _uuid = uuid ?? const Uuid();

  /// Screen 08: habit.create from a [draft] of [type], validated as the server would (I1), with
  /// an optional first reminder in the same transaction. Starts on [startLocalDate] (default:
  /// today in the account calendar). Throws [HabitEditFailure.invalid] without writing.
  Future<String> createHabit(
    HabitDraft draft, {
    required String type,
    NewReminder? reminder,
    LocalDate? startLocalDate,
    ProvisionalTypeRegistry? types,
  }) {
    final problems = draft.problems((types ?? ProvisionalTypeRegistry.builtins()).lookup(type));
    if (problems.isNotEmpty) return Future.error(HabitEditFailure.invalid(problems));
    return db.transaction(() async {
      final p = draft.toPayload();
      final id = await createHabitUnchecked(
        name: p['name']! as String,
        type: type,
        target: p['target_value']!,
        unit: p['unit'] as String?,
        category: p['category']! as String,
        frequencyType: p['frequency_type']! as String,
        frequencyConfig: (p['frequency_config']! as Map).cast<String, Object?>(),
        startLocalDate: startLocalDate ?? (await _calendar()).today(clock()),
      );
      if (reminder != null) {
        await createReminder(
          habitId: id,
          localTime: reminder.localTime,
          daysOfWeek: reminder.daysOfWeek,
          timezoneMode: 'device_zone',
          enabled: reminder.enabled,
        );
      }
      return id;
    });
  }

  /// habit.create with a client-generated UUIDv7 id (spec 05), as given: no validation. The app
  /// creates through [createHabit]; tests and tools use this to set up any state, including
  /// what the server would refuse. Returns the habit id.
  Future<String> createHabitUnchecked({
    required String name,
    required String type,
    required Object target,
    String? unit,
    required String category,
    String frequencyType = 'daily',
    Map<String, Object?> frequencyConfig = const {},
    required LocalDate startLocalDate,
    bool backdate = false,
  }) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final id = _uuid.v7();
      await _append(
        entity: 'habit',
        entityId: id,
        operation: 'habit.create',
        baseVersion: null,
        calendar: calendar,
        localDate: null,
        habitId: id,
        payload: {
          'name': name,
          'type': type,
          'target_value': target,
          'unit': unit,
          'category': category,
          'frequency_type': frequencyType,
          'frequency_config': frequencyConfig,
          'start_local_date': startLocalDate.toString(),
          if (backdate) 'date_mode': 'backdate',
        },
      );
      return id;
    });
  }

  /// habit.update (A34): the whole editable state (six keys, never `type`), validated as the
  /// server would. Writes nothing when [draft] equals what the habit shows. While the habit's
  /// habit.create is unsent, the create's payload is patched instead; a second unsent update
  /// coalesces into the first. Throws [HabitEditFailure] without writing (also while the habit
  /// shows as archived, L2).
  Future<void> updateHabit(String habitId, HabitDraft draft, {ProvisionalTypeRegistry? types}) {
    return db.transaction(() async {
      final state = await _habitState(habitId);
      if (state.archived) throw const HabitEditFailure.archived();
      final rules = (types ?? ProvisionalTypeRegistry.builtins()).lookup(state.type);
      final problems = draft.problems(rules);
      if (problems.isNotEmpty) throw HabitEditFailure.invalid(problems);
      if (draft.sameAs(HabitDraft.fromWire(state.shown), rules)) return;
      final payload = draft.toPayload();

      // L1: fold into the unsent create only while it is the newest queued row for the habit; a
      // row queued after it (an update made while the create was in flight) would replay over it.
      final unacked = state.rows.where((r) => OutboxState.unacked.contains(r.state)).toList();
      final create = state.unsentCreate;
      if (create != null && unacked.last.seq == create.seq) {
        final merged = (jsonDecode(create.payload) as Map).cast<String, Object?>()..addAll(payload);
        await _rewrite(create, merged);
        return;
      }
      // Otherwise the newest queued update, while unsent, takes the whole new state (same
      // mutation id and base version); archive and restore rows after it carry no fields.
      final update = unacked.where((r) => r.operation == 'habit.update').lastOrNull;
      if (update != null && update.state == OutboxState.pending) {
        await _rewrite(update, payload);
        return;
      }
      await _append(
        entity: 'habit',
        entityId: habitId,
        operation: 'habit.update',
        baseVersion: state.baseVersion,
        calendar: await _calendar(),
        localDate: null,
        habitId: habitId,
        payload: payload,
      );
    });
  }

  /// habit.archive (A34). Writes nothing when the habit already shows as archived; never
  /// coalesces.
  Future<void> archiveHabit(String habitId) => _archiveOrRestore(habitId, archive: true);

  /// habit.restore (A34). Writes nothing when the habit already shows as active.
  Future<void> restoreHabit(String habitId) => _archiveOrRestore(habitId, archive: false);

  Future<void> _archiveOrRestore(String habitId, {required bool archive}) {
    return db.transaction(() async {
      final state = await _habitState(habitId);
      if (state.archived == archive) return;
      await _append(
        entity: 'habit',
        entityId: habitId,
        operation: archive ? 'habit.archive' : 'habit.restore',
        baseVersion: state.baseVersion,
        calendar: await _calendar(),
        localDate: null,
        habitId: habitId,
        payload: const {},
      );
    });
  }

  /// What one habit looks like from this device: confirmed row, queued rows (oldest first),
  /// the editable state it shows and the base version a new row gets.
  Future<_HabitState> _habitState(String habitId) async {
    final confirmed = await (db.select(
      db.habits,
    )..where((h) => h.id.equals(habitId))).getSingleOrNull();
    final rows =
        await (db.select(db.outbox)
              ..where(
                (o) =>
                    o.entity.equals('habit') &
                    o.entityId.equals(habitId) &
                    o.state.isIn([...OutboxState.unacked, OutboxState.acked]),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
            .get();
    final create = rows.where((r) => r.operation == 'habit.create').firstOrNull;
    if (confirmed == null && create == null) throw const HabitEditFailure.unknownHabit();
    final unacked = rows.where((r) => OutboxState.unacked.contains(r.state)).toList();
    if (unacked.isNotEmpty && unacked.last.state == OutboxState.needsAttention) {
      // Never queue behind a change the person still has to look at (screen 18 / 19).
      throw const HabitEditFailure.needsAttention();
    }

    final base = confirmed == null
        ? (jsonDecode(create!.payload) as Map).cast<String, dynamic>()
        : EntityCodec.habitPayload(confirmed);
    final shown = <String, dynamic>{...base};
    var archived = confirmed?.archivedAt != null || shown['archived_at'] != null;
    for (final row in unacked) {
      if (row.operation == 'habit.update') {
        shown.addAll((jsonDecode(row.payload) as Map).cast<String, dynamic>());
      } else if (row.operation == 'habit.archive') {
        archived = true;
      } else if (row.operation == 'habit.restore') {
        archived = false;
      }
    }

    // The newest version this device has seen; a row queued behind an unacknowledged one
    // carries it as a placeholder and the engine rebases it from that row's ack (F4). Behind a
    // create still in flight there is no version yet: null, filled by the rebase.
    int? baseVersion = confirmed?.version;
    for (final row in rows) {
      if (row.state == OutboxState.acked && (row.ackVersion ?? 0) > (baseVersion ?? 0)) {
        baseVersion = row.ackVersion;
      }
    }
    return _HabitState(
      type: (confirmed?.type ?? shown['type']) as String? ?? '',
      rows: rows,
      shown: shown,
      archived: archived,
      baseVersion: baseVersion,
      unsentCreate: create != null && create.state == OutboxState.pending && confirmed == null
          ? create
          : null,
    );
  }

  Future<void> _rewrite(OutboxRow row, Map<String, Object?> payload) =>
      (db.update(db.outbox)..where((o) => o.seq.equals(row.seq))).write(
        OutboxCompanion(payload: Value(jsonEncode(payload))),
      );

  /// log.set_value for the habit-day of [at] (default: now on the server's clock, F10) in the
  /// server's calendar.
  ///
  /// With [logDate] it is a past check-in (screen 13): date_mode "backdate" + log_date, filed
  /// under that date, with occurred_at still the real moment of the write (never invented).
  /// Dates the server would refuse (after the local today, more than 30 days back) throw
  /// [DayResolutionException] and write nothing.
  Future<LocalWrite> setLogValue({
    required String habitId,
    required Object value,
    DateTime? at,
    LocalDate? logDate,
  }) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final occurredAt = (at ?? calendar.now(clock())).toUtc();
      if (logDate != null) {
        DayResolver(calendar.timeline, () => occurredAt).validateBackdate(logDate);
      }
      final date = logDate ?? calendar.timeline.localDateAt(occurredAt);
      final rows = await _rowsFor(habitId, date);

      // Coalesce only into the newest row for this habit-day, only while it is unsent.
      final last = rows.isEmpty ? null : rows.last;
      if (last != null && last.state == OutboxState.pending && last.operation == 'log.set_value') {
        final payload = (jsonDecode(last.payload) as Map).cast<String, Object?>()
          ..['value'] = value;
        await (db.update(db.outbox)..where((o) => o.seq.equals(last.seq))).write(
          OutboxCompanion(payload: Value(jsonEncode(payload)), occurredAt: Value(_iso(occurredAt))),
        );
        return LocalWrite(last.mutationId, date, coalesced: true);
      }

      final confirmed = await _confirmedLog(habitId, date);
      final mutationId = await _append(
        entity: 'habit_log',
        entityId: confirmed?.id ?? last?.entityId ?? _uuid.v7(),
        operation: 'log.set_value',
        // A tombstone's version here is an explicit restore (A29).
        baseVersion: _baseVersion(confirmed, rows),
        calendar: calendar,
        localDate: date,
        habitId: habitId,
        occurredAt: occurredAt,
        payload: {
          'habit_id': habitId,
          'value': value,
          if (logDate != null) ...{'date_mode': 'backdate', 'log_date': logDate.toString()},
        },
      );
      return LocalWrite(mutationId, date, coalesced: false);
    });
  }

  /// log.increment (A35): adds [delta] to the habit-day of [at] (or the backdated [logDate]),
  /// with setLogValue's day rules. Validated by the habit's type rules on the day's value as
  /// this device shows it; a refused delta throws [LogFailure] and writes nothing. No base
  /// version: increments merge on the server and never conflict with each other.
  ///
  /// A2: folds into the newest row for the habit-day only when that row is a PENDING increment
  /// (the deltas added by the type rule; it keeps its id and takes the newer occurred_at).
  /// A3: on a day that shows deleted, the write is a log.set_value of the delta on the
  /// tombstone's version, an explicit restore (A29), as setLogValue does.
  Future<LocalWrite> incrementLog({
    required String habitId,
    required Object delta,
    DateTime? at,
    LocalDate? logDate,
    ProvisionalTypeRegistry? types,
  }) {
    return db.transaction(() async {
      final rules = (types ?? ProvisionalTypeRegistry.builtins()).lookup(
        await habitTypeOf(db, habitId) ?? '',
      );
      final calendar = await _calendar();
      final occurredAt = (at ?? calendar.now(clock())).toUtc();
      if (logDate != null) {
        DayResolver(calendar.timeline, () => occurredAt).validateBackdate(logDate);
      }
      final date = logDate ?? calendar.timeline.localDateAt(occurredAt);
      final rows = await _rowsFor(habitId, date);
      final confirmed = await _confirmedLog(habitId, date);
      final day = applyLogRows(confirmed: confirmed, rows: rows, rules: rules);

      final units = rules?.parseValue(delta);
      final current = rules?.parseValue(day.value) ?? 0;
      if (rules == null ||
          units == null ||
          rules.increment(day.deleted ? 0 : current, delta) == null) {
        throw const LogFailure(LogFailureKind.invalidDelta);
      }
      final wire = rules.formatValue(units);

      if (day.deleted) {
        // ASSUMPTION(4.3a-increment-deleted-day): the person adding to a day this device shows
        // as deleted means to bring it back with that amount.
        return setLogValue(habitId: habitId, value: wire, at: occurredAt, logDate: logDate);
      }

      final last = rows.isEmpty ? null : rows.last;
      if (last != null && last.state == OutboxState.pending && last.operation == 'log.increment') {
        final payload = (jsonDecode(last.payload) as Map).cast<String, Object?>();
        final folded = rules.increment(rules.parseValue(payload['delta']) ?? 0, wire);
        if (folded != null) {
          payload['delta'] = rules.formatValue(folded);
          await (db.update(db.outbox)..where((o) => o.seq.equals(last.seq))).write(
            OutboxCompanion(
              payload: Value(jsonEncode(payload)),
              occurredAt: Value(_iso(occurredAt)),
            ),
          );
          return LocalWrite(last.mutationId, date, coalesced: true);
        }
      }

      final mutationId = await _append(
        entity: 'habit_log',
        entityId: confirmed?.id ?? last?.entityId ?? _uuid.v7(),
        operation: 'log.increment',
        baseVersion: null,
        calendar: calendar,
        localDate: date,
        habitId: habitId,
        occurredAt: occurredAt,
        payload: {
          'habit_id': habitId,
          'delta': wire,
          if (logDate != null) ...{'date_mode': 'backdate', 'log_date': logDate.toString()},
        },
      );
      return LocalWrite(mutationId, date, coalesced: false);
    });
  }

  // A36: timer drafts. Local only: never in the outbox, never synced. Each call is one
  // transaction; the clock is the injected one, and no platform timer runs here.

  /// Starts a timer for [habitId]; a habit that already has a draft gets it back unchanged.
  Future<TimerDraftView> startTimer(String habitId) => db.transaction(() async {
    await _timerAllowed(habitId);
    final existing = await _draft(habitId);
    if (existing != null) return TimerDraftView(existing);
    final now = clock().millisecondsSinceEpoch;
    await db
        .into(db.timerDrafts)
        .insert(
          TimerDraftsCompanion.insert(
            habitId: habitId,
            state: TimerDraftView.running,
            elapsedMs: 0,
            runningSince: Value(now),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return TimerDraftView((await _draft(habitId))!);
  });

  /// Banks the running span; a paused draft stays as it is.
  Future<TimerDraftView> pauseTimer(String habitId) => db.transaction(() async {
    await _timerAllowed(habitId);
    final draft = await _requireDraft(habitId);
    if (draft.state != TimerDraftView.running) return TimerDraftView(draft);
    final now = clock().millisecondsSinceEpoch;
    return _writeDraft(
      draft,
      TimerDraftsCompanion(
        state: const Value(TimerDraftView.paused),
        elapsedMs: Value(TimerDraftView(draft).elapsedAt(now)),
        runningSince: const Value(null),
        updatedAt: Value(now),
      ),
    );
  });

  /// Runs a paused draft again from now; a running draft stays as it is.
  Future<TimerDraftView> resumeTimer(String habitId) => db.transaction(() async {
    await _timerAllowed(habitId);
    final draft = await _requireDraft(habitId);
    if (draft.state == TimerDraftView.running) return TimerDraftView(draft);
    final now = clock().millisecondsSinceEpoch;
    return _writeDraft(
      draft,
      TimerDraftsCompanion(
        state: const Value(TimerDraftView.running),
        runningSince: Value(now),
        updatedAt: Value(now),
      ),
    );
  });

  /// A36 finish: whole seconds of the elapsed time. Zero removes the draft and writes nothing
  /// (null). Otherwise the draft is removed and a log.increment of the seconds is queued, filed
  /// under the habit-day of this moment, in ONE transaction (invariant 8): a refused increment
  /// ([LogFailure]) leaves the draft. More than a day can hold throws [TimerFailureKind.tooLong]
  /// and leaves the draft.
  Future<LocalWrite?> finishTimer(String habitId, {ProvisionalTypeRegistry? types}) =>
      db.transaction(() async {
        final rules = await _timerAllowed(habitId, types: types);
        final draft = await _requireDraft(habitId);
        final seconds = TimerDraftView(draft).elapsedAt(clock().millisecondsSinceEpoch) ~/ 1000;
        await (db.delete(db.timerDrafts)..where((t) => t.habitId.equals(habitId))).go();
        if (seconds == 0) return null;
        if (rules.parseValue(rules.formatValue(seconds)) == null) {
          throw const TimerFailure(TimerFailureKind.tooLong);
        }
        return incrementLog(habitId: habitId, delta: rules.formatValue(seconds), types: types);
      });

  /// Throws the draft away; nothing is written.
  Future<void> discardTimer(String habitId) => db.transaction(() async {
    await (db.delete(db.timerDrafts)..where((t) => t.habitId.equals(habitId))).go();
  });

  /// The habit's draft as it changes; null without one.
  Stream<TimerDraftView?> watchTimer(String habitId) =>
      (db.select(db.timerDrafts)..where((t) => t.habitId.equals(habitId))).watchSingleOrNull().map(
        (d) => d == null ? null : TimerDraftView(d),
      );

  Future<TimerDraft?> _draft(String habitId) =>
      (db.select(db.timerDrafts)..where((t) => t.habitId.equals(habitId))).getSingleOrNull();

  Future<TimerDraft> _requireDraft(String habitId) async =>
      await _draft(habitId) ?? (throw const TimerFailure(TimerFailureKind.noDraft));

  Future<TimerDraftView> _writeDraft(TimerDraft draft, TimerDraftsCompanion change) async {
    await (db.update(db.timerDrafts)..where((t) => t.habitId.equals(draft.habitId))).write(change);
    return TimerDraftView((await _draft(draft.habitId))!);
  }

  /// The habit's rules when it may be timed: a type whose rules support a timer (B2), and not
  /// archived on this device.
  Future<ProvisionalTypeRules> _timerAllowed(
    String habitId, {
    ProvisionalTypeRegistry? types,
  }) async {
    final rules = (types ?? ProvisionalTypeRegistry.builtins()).lookup(
      await habitTypeOf(db, habitId) ?? '',
    );
    if (rules == null || !rules.supportsTimer) {
      throw const TimerFailure(TimerFailureKind.notSupported);
    }
    bool archived;
    try {
      archived = (await _habitState(habitId)).archived;
    } on HabitEditFailure catch (e) {
      if (e.kind == HabitEditFailureKind.unknownHabit) {
        throw const TimerFailure(TimerFailureKind.notSupported);
      }
      // A change that needs a look does not stop a timer; its check-in queues behind it.
      archived = false;
    }
    if (archived) throw const TimerFailure(TimerFailureKind.archived);
    return rules;
  }

  /// profile.set_timezone (screen 04): entity user, id = the user id, base_version = the
  /// confirmed user version. The server applies it from the start of the next day (A26), or
  /// cancels a pending change when [timezone] is the zone in force. Unsent rows coalesce: the
  /// latest choice wins.
  Future<String> setTimezone(String timezone) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final state = await (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingle();
      final pending =
          await (db.select(db.outbox)
                ..where(
                  (o) =>
                      o.operation.equals('profile.set_timezone') &
                      o.state.equals(OutboxState.pending),
                )
                ..orderBy([(o) => OrderingTerm.desc(o.seq)])
                ..limit(1))
              .getSingleOrNull();
      if (pending != null) {
        final now = calendar.now(clock()).toUtc();
        await (db.update(db.outbox)..where((o) => o.seq.equals(pending.seq))).write(
          OutboxCompanion(
            payload: Value(jsonEncode({'timezone': timezone})),
            occurredAt: Value(_iso(now)),
            capturedTimezone: Value(calendar.zoneAt(now)),
          ),
        );
        return pending.mutationId;
      }
      final user = jsonDecode(state.userPayload ?? '{}');
      final version = user is Map && user['version'] is int ? user['version'] as int : null;
      return _append(
        entity: 'user',
        entityId: state.userId,
        operation: 'profile.set_timezone',
        baseVersion: version,
        calendar: calendar,
        localDate: null,
        habitId: null,
        payload: {'timezone': timezone},
      );
    });
  }

  /// profile.update (A20): the whole desired state, so the payload always carries all three
  /// keys (null clears city or country). Entity user, id = the user id, base_version = the
  /// confirmed user version. A second unsent profile.update coalesces into the first and keeps
  /// its base_version (as reminder.update does). Inputs are trimmed; an empty city is null.
  Future<String> updateProfile({
    required String name,
    required String? city,
    required String? countryCode,
  }) {
    final trimmedCity = city?.trim();
    final payload = <String, Object?>{
      'name': name.trim(),
      'city': trimmedCity == null || trimmedCity.isEmpty ? null : trimmedCity,
      'country_code': countryCode,
    };
    return db.transaction(() async {
      final calendar = await _calendar();
      final state = await (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingle();
      final pending =
          await (db.select(db.outbox)
                ..where(
                  (o) => o.operation.equals('profile.update') & o.state.equals(OutboxState.pending),
                )
                ..orderBy([(o) => OrderingTerm.desc(o.seq)])
                ..limit(1))
              .getSingleOrNull();
      if (pending != null) {
        await (db.update(db.outbox)..where((o) => o.seq.equals(pending.seq))).write(
          OutboxCompanion(payload: Value(jsonEncode(payload))),
        );
        return pending.mutationId;
      }
      final user = jsonDecode(state.userPayload ?? '{}');
      final version = user is Map && user['version'] is int ? user['version'] as int : null;
      return _append(
        entity: 'user',
        entityId: state.userId,
        operation: 'profile.update',
        baseVersion: version,
        calendar: calendar,
        localDate: null,
        habitId: null,
        payload: payload,
      );
    });
  }

  /// log.delete for one habit-day. Carries habit_id + log_date so the server can resolve it
  /// even if the id never reached it (A29).
  Future<LocalWrite> deleteLog({required String habitId, required LocalDate date}) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final rows = await _rowsFor(habitId, date);
      final confirmed = await _confirmedLog(habitId, date);
      if (confirmed == null && rows.isEmpty) {
        throw StateError('Nothing to delete for $habitId on $date.');
      }
      final mutationId = await _append(
        entity: 'habit_log',
        entityId: confirmed?.id ?? rows.last.entityId,
        operation: 'log.delete',
        baseVersion: _baseVersion(confirmed, rows),
        calendar: calendar,
        localDate: date,
        habitId: habitId,
        payload: {'habit_id': habitId, 'log_date': date.toString()},
      );
      return LocalWrite(mutationId, date, coalesced: false);
    });
  }

  /// reminder.create (Phase 3.2b): a clock time and ISO days for one habit. Returns the id.
  Future<String> createReminder({
    required String habitId,
    required String localTime,
    required List<int> daysOfWeek,
    String timezoneMode = 'habit_zone',
    String? timezone,
    bool enabled = true,
  }) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final id = _uuid.v7();
      await _append(
        entity: 'reminder',
        entityId: id,
        operation: 'reminder.create',
        baseVersion: null,
        calendar: calendar,
        localDate: null,
        habitId: habitId,
        payload: {
          'habit_id': habitId,
          ..._reminderFields(localTime, daysOfWeek, timezoneMode, timezone, enabled),
        },
      );
      return id;
    });
  }

  /// reminder.update: the whole desired state (absolute). Coalesces into an unsent create or
  /// update for the same reminder, so a burst of edits sends one change.
  Future<void> updateReminder({
    required String reminderId,
    required String localTime,
    required List<int> daysOfWeek,
    String timezoneMode = 'habit_zone',
    String? timezone,
    bool enabled = true,
  }) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final fields = _reminderFields(localTime, daysOfWeek, timezoneMode, timezone, enabled);
      final rows = await _reminderRows(reminderId);
      final last = rows.isEmpty ? null : rows.last;
      if (last != null &&
          last.state == OutboxState.pending &&
          (last.operation == 'reminder.create' || last.operation == 'reminder.update')) {
        final payload = (jsonDecode(last.payload) as Map).cast<String, Object?>()..addAll(fields);
        await (db.update(db.outbox)..where((o) => o.seq.equals(last.seq))).write(
          OutboxCompanion(payload: Value(jsonEncode(payload))),
        );
        return;
      }
      final habitId = await _reminderHabit(reminderId, rows);
      await _append(
        entity: 'reminder',
        entityId: reminderId,
        operation: 'reminder.update',
        baseVersion: await _reminderBase(reminderId, rows),
        calendar: calendar,
        localDate: null,
        habitId: habitId,
        payload: fields,
      );
    });
  }

  /// reminder.delete: a tombstone on the server. Appended even behind an unsent create (an
  /// unacknowledged row is never deleted, invariant 8).
  Future<void> deleteReminder(String reminderId) {
    return db.transaction(() async {
      final calendar = await _calendar();
      final rows = await _reminderRows(reminderId);
      await _append(
        entity: 'reminder',
        entityId: reminderId,
        operation: 'reminder.delete',
        baseVersion: await _reminderBase(reminderId, rows),
        calendar: calendar,
        localDate: null,
        habitId: await _reminderHabit(reminderId, rows),
        payload: const {},
      );
    });
  }

  static Map<String, Object?> _reminderFields(
    String localTime,
    List<int> days,
    String timezoneMode,
    String? timezone,
    bool enabled,
  ) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(localTime)) {
      throw ArgumentError.value(localTime, 'localTime', 'must be HH:MM');
    }
    final sorted = {...days}.toList()..sort();
    if (sorted.isEmpty || sorted.any((d) => d < 1 || d > 7)) {
      throw ArgumentError.value(days, 'daysOfWeek', 'must be ISO days 1..7');
    }
    return {
      'local_time': localTime,
      'days_of_week': sorted,
      'timezone_mode': timezoneMode,
      'timezone': timezone,
      'enabled': enabled,
    };
  }

  Future<List<OutboxRow>> _reminderRows(String reminderId) =>
      (db.select(db.outbox)
            ..where(
              (o) =>
                  o.entity.equals('reminder') &
                  o.entityId.equals(reminderId) &
                  o.state.isIn([...OutboxState.unacked, OutboxState.acked]),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
          .get();

  /// The newest version this device has seen (confirmed or acked); a placeholder behind an
  /// unacknowledged row, rebased by the engine from that row's ack (F4).
  Future<int> _reminderBase(String reminderId, List<OutboxRow> rows) async {
    final confirmed = await (db.select(
      db.reminders,
    )..where((r) => r.id.equals(reminderId))).getSingleOrNull();
    var version = confirmed?.version ?? 0;
    for (final row in rows) {
      if (row.state == OutboxState.acked && (row.ackVersion ?? 0) > version) {
        version = row.ackVersion!;
      }
    }
    return version;
  }

  Future<String?> _reminderHabit(String reminderId, List<OutboxRow> rows) async {
    final confirmed = await (db.select(
      db.reminders,
    )..where((r) => r.id.equals(reminderId))).getSingleOrNull();
    return confirmed?.habitId ?? rows.firstOrNull?.habitId;
  }

  /// Screen 18 "Discard": the user gives up a change the server would not take. Only rows in
  /// needs_attention qualify (they are never resubmitted automatically); the row moves to
  /// discarded_mutations in the same transaction, so the decision is recorded, not lost.
  /// Returns false when the row is gone or not in needs_attention.
  Future<bool> discard(String mutationId) {
    return db.transaction(() async {
      final row = await (db.select(
        db.outbox,
      )..where((o) => o.mutationId.equals(mutationId))).getSingleOrNull();
      if (row == null || row.state != OutboxState.needsAttention) return false;
      await db
          .into(db.discardedMutations)
          .insert(
            DiscardedMutationsCompanion.insert(
              mutationId: row.mutationId,
              entity: row.entity,
              entityId: row.entityId,
              operation: row.operation,
              payload: row.payload,
              localDateHint: Value(row.localDateHint),
              lastError: Value(row.lastError),
              discardedAt: clock().toUtc().millisecondsSinceEpoch,
            ),
          );
      await (db.delete(db.outbox)..where((o) => o.seq.equals(row.seq))).go();
      return true;
    });
  }

  /// Screen 18 "Try again": a blocked row becomes due now instead of after its backoff.
  Future<bool> retryNow(String mutationId) async {
    final updated =
        await (db.update(db.outbox)
              ..where((o) => o.mutationId.equals(mutationId) & o.state.equals(OutboxState.blocked)))
            .write(const OutboxCompanion(nextAttemptAt: Value(0)));
    return updated == 1;
  }

  /// The newest version this device has seen for the habit-day (confirmed or acked). Rows queued
  /// behind an unacknowledged one carry it only as a placeholder: the engine sends one row per
  /// habit-day at a time and rebases the next from the server's ack (F4). The client never
  /// predicts versions.
  int _baseVersion(ConfirmedLog? confirmed, List<OutboxRow> rows) {
    var version = confirmed?.version ?? 0;
    for (final row in rows) {
      if (row.state == OutboxState.acked && (row.ackVersion ?? 0) > version) {
        version = row.ackVersion!;
      }
    }
    return version;
  }

  Future<List<OutboxRow>> _rowsFor(String habitId, LocalDate date) =>
      (db.select(db.outbox)
            ..where(
              (o) =>
                  o.entity.equals('habit_log') &
                  o.habitId.equals(habitId) &
                  o.localDateHint.equals(date.toString()) &
                  o.state.isIn([...OutboxState.unacked, OutboxState.acked]),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.seq)]))
          .get();

  Future<ConfirmedLog?> _confirmedLog(String habitId, LocalDate date) =>
      (db.select(db.habitLogs)
            ..where((l) => l.habitId.equals(habitId) & l.logDate.equals(date.toString()))
            ..orderBy([(l) => OrderingTerm.desc(l.version)])
            ..limit(1))
          .getSingleOrNull();

  Future<String> _append({
    required String entity,
    required String entityId,
    required String operation,
    required int? baseVersion,
    required AccountCalendar calendar,
    required LocalDate? localDate,
    required String? habitId,
    required Map<String, Object?> payload,
    DateTime? occurredAt,
  }) async {
    final mutationId = _uuid.v7();
    final now = clock().toUtc();
    final serverNow = calendar.now(now);
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            mutationId: mutationId,
            entity: entity,
            entityId: entityId,
            operation: operation,
            baseVersion: Value(baseVersion),
            occurredAt: _iso(occurredAt ?? serverNow),
            // A5: the habit-calendar zone in force at the event, never the device zone.
            capturedTimezone: Value(calendar.zoneAt(occurredAt ?? serverNow)),
            localDateHint: Value(localDate?.toString()),
            payload: jsonEncode(payload),
            habitId: Value(habitId),
            state: OutboxState.pending,
            createdAt: now.millisecondsSinceEpoch,
          ),
        );
    return mutationId;
  }

  Future<AccountCalendar> _calendar() async {
    final calendar = await AccountCalendar.load(db, deviceNow: clock());
    if (calendar == null) {
      throw StateError('The server calendar is not known yet: sign in or sync first.');
    }
    return calendar;
  }

  static String _iso(DateTime t) {
    final utc = t.toUtc();
    final ms = utc.millisecond;
    final base = utc.toIso8601String().split('.').first;
    return ms == 0 ? '${base}Z' : '$base.${ms.toString().padLeft(3, '0')}Z';
  }
}

class _HabitState {
  final String type;
  final List<OutboxRow> rows;
  final Map<String, dynamic> shown;
  final bool archived;
  final int? baseVersion;
  final OutboxRow? unsentCreate;

  const _HabitState({
    required this.type,
    required this.rows,
    required this.shown,
    required this.archived,
    required this.baseVersion,
    required this.unsentCreate,
  });
}

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

/// A timer action that was not done (A36).
class TimerFailure implements Exception {
  final TimerFailureKind kind;

  const TimerFailure(this.kind);

  @override
  String toString() => 'TimerFailure($kind)';
}

enum TimerFailureKind {
  /// The habit's type has no timer (or the habit is unknown here).
  notSupported,

  /// The habit shows as archived.
  archived,

  /// No draft for this habit.
  noDraft,

  /// More time than one habit-day can hold.
  tooLong,
}

/// A log write that was not made (4.3a).
class LogFailure implements Exception {
  final LogFailureKind kind;

  const LogFailure(this.kind);

  @override
  String toString() => 'LogFailure($kind)';
}

enum LogFailureKind {
  /// The delta breaks the habit's type rules (not positive, too precise, over a day's limit, a
  /// type without increments such as yes / no, or a type this app does not know).
  invalidDelta,
}

/// The first reminder of a habit created on screen 08. It follows the device's local time, as
/// the design's row says.
class NewReminder {
  final String localTime;
  final List<int> daysOfWeek;
  final bool enabled;

  const NewReminder({
    required this.localTime,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.enabled = true,
  });
}

/// A habit create, edit, archive or restore that was not written (A34, I1); 4.2b shows it.
class HabitEditFailure implements Exception {
  final HabitEditFailureKind kind;
  final List<HabitDraftProblem> problems;

  const HabitEditFailure._(this.kind, this.problems);
  const HabitEditFailure.invalid(List<HabitDraftProblem> problems)
    : this._(HabitEditFailureKind.invalid, problems);
  const HabitEditFailure.needsAttention() : this._(HabitEditFailureKind.needsAttention, const []);
  const HabitEditFailure.unknownHabit() : this._(HabitEditFailureKind.unknownHabit, const []);
  const HabitEditFailure.archived() : this._(HabitEditFailureKind.archived, const []);

  @override
  String toString() => 'HabitEditFailure($kind, $problems)';
}

enum HabitEditFailureKind {
  /// The draft breaks a rule the server would refuse ([HabitEditFailure.problems]).
  invalid,

  /// The habit's newest change needs a look first: open the resolve flow.
  needsAttention,

  /// No such habit on this device.
  unknownHabit,

  /// The habit shows as archived (confirmed, or a queued archive not undone by a restore):
  /// restore it first (L2).
  archived,
}

class LocalWrite {
  final String mutationId;
  final LocalDate date;
  final bool coalesced;

  const LocalWrite(this.mutationId, this.date, {required this.coalesced});
}
