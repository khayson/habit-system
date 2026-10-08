import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/local_mutation_service.dart';
import 'package:habit/data/local_view.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/domain/calendar/timezone_timeline.dart';
import 'package:habit/sync/sync_engine.dart';
import 'package:habit/sync/sync_transport.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../support/fake_sync_server.dart';

/// One device: its account database, writer, view and engine, talking to [server].
class Device {
  Device(
    this.server, {
    QueryExecutor? executor,
    this.deviceId = '01970000-0000-7000-8000-00000000d001',
  }) : db = AppDatabase(executor ?? NativeDatabase.memory());

  final FakeSyncServer server;
  final AppDatabase db;
  final String deviceId;
  DateTime now = DateTime.utc(2026, 5, 28, 17, 22);

  late final writer = LocalMutationService(db, clock: () => now);
  late final view = LocalView(db);

  static void loadZones() {
    ensureTimeZonesLoaded(tzdata.initializeTimeZones);
    // Tests open several devices, each with its own in-memory database.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  Future<Device> init() async {
    await initAccountState(db, userId: 'user-1', deviceId: deviceId, user: server.user);
    return this;
  }

  SyncEngine engine({
    SyncTransport? transport,
    Future<void> Function()? beforeApplyCommit,
    Future<void> Function()? betweenSelectAndMark,
    String? owner,
    String? appVersion,
  }) => SyncEngine(
    db: db,
    transport: transport ?? server,
    capabilities: const ['binary', 'quantity', 'duration'],
    clock: () => now,
    random: Random(1),
    ownerId: owner,
    appVersion: appVersion,
    beforeApplyCommit: beforeApplyCommit,
    betweenSelectAndMark: betweenSelectAndMark,
  );

  Future<SyncOutcome> sync({bool force = false}) => engine().run(force: force);

  Future<String> habit({String type = 'binary', Object target = 1}) => writer.createHabit(
    name: 'Stretch',
    type: type,
    target: target,
    category: 'health',
    startLocalDate: LocalDate.parse('2026-05-01'),
  );

  Future<List<OutboxRow>> outbox() =>
      (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.seq)])).get();

  Future<SyncStateRow> state() =>
      (db.select(db.syncState)..where((s) => s.id.equals(1))).getSingle();

  Future<List<ConfirmedLog>> logs() => db.select(db.habitLogs).get();
}
