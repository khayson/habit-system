import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/database_opener.dart';
import 'package:path/path.dart' as p;

/// A23 spike, host side. Proves the two layers of the chosen approach
/// (docs/adr/0001-multi-isolate-drift.md):
///  1. a shared drift server isolate that other isolates connect to by port (what
///     `shareAcrossIsolates` does through IsolateNameServer), with cross-isolate streams;
///  2. the WAL + busy_timeout connection setup that keeps two independent connections from
///     different isolates safe if they ever coexist.
/// The device-side test in integration_test/ runs the real `openAccountDatabase` on Android.

const _rowsPerWriter = 300;

Future<void> _createScratchTable(DatabaseConnectionUser db) => db.customStatement(
  'CREATE TABLE IF NOT EXISTS spike (id INTEGER PRIMARY KEY, writer TEXT NOT NULL)',
);

Future<void> _insertRows(DatabaseConnectionUser db, String writer) async {
  for (var i = 0; i < _rowsPerWriter; i++) {
    await db.transaction(
      () => db.customInsert('INSERT INTO spike (writer) VALUES (?)', variables: [Variable(writer)]),
    );
  }
}

/// Like [_insertRows], but a transaction SQLite refuses to begin is tried again. With two
/// independent WAL connections SQLite may refuse BEGIN IMMEDIATE at once (SQLITE_BUSY without
/// consulting busy_timeout, seen once on Linux CI). A refused BEGIN wrote nothing, so a retry can
/// neither lose nor double a row; returns how many retries were needed.
Future<int> _insertRowsRetrying(DatabaseConnectionUser db, String writer) async {
  var retries = 0;
  for (var i = 0; i < _rowsPerWriter; i++) {
    while (true) {
      try {
        await db.transaction(
          () => db.customInsert(
            'INSERT INTO spike (writer) VALUES (?)',
            variables: [Variable(writer)],
          ),
        );
        break;
      } on SqliteException catch (e) {
        if (e.resultCode != 5 || retries >= 50) rethrow; // 5 = SQLITE_BUSY
        retries++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }
  }
  return retries;
}

Future<int> _count(DatabaseConnectionUser db) async =>
    (await db.customSelect('SELECT COUNT(*) AS c FROM spike').getSingle()).read<int>('c');

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('habit_spike_');
    file = File(p.join(dir.path, 'habit_test.sqlite'));
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold the WAL files briefly; the OS cleans temp.
    }
  });

  test('boots schema v5: WAL, synchronous FULL, foreign keys on', () async {
    final db = AppDatabase(NativeDatabase(file, setup: configureConnection));

    final userVersion = await db.customSelect('PRAGMA user_version').getSingle();
    final journal = await db.customSelect('PRAGMA journal_mode').getSingle();
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    final synchronous = await db.customSelect('PRAGMA synchronous').getSingle();
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
          'ORDER BY name',
        )
        .get();

    expect(db.schemaVersion, 5);
    expect(userVersion.data.values.single, 5);
    expect(journal.data.values.single, 'wal');
    expect(fk.data.values.single, 1);
    expect(synchronous.data.values.single, 2, reason: 'synchronous = FULL (2)');
    expect(tables.map((t) => t.read<String>('name')), [
      'calendar_entries',
      'discarded_mutations',
      'habit_logs',
      'habit_progress',
      'habits',
      'local_settings',
      'opaque_entities',
      'outbox',
      'period_evaluations',
      'sync_state',
    ]);
    await db.close();
  });

  test('a second isolate writes through the shared server; streams see it', () async {
    final path = file.path;
    final server = await DriftIsolate.spawn(
      () => NativeDatabase(File(path), setup: configureConnection),
    );
    final main = AppDatabase(await server.connect());
    await _createScratchTable(main);

    // The UI side listens for table updates. Only the background isolate announces its
    // writes, so receiving one proves notifications cross isolates through the server.
    final notified = main.tableUpdates(const TableUpdateQuery.onTableName('spike')).first;

    final port = server.connectPort;
    await Future.wait([
      Isolate.run(() async {
        final background = AppDatabase(await DriftIsolate.fromConnectPort(port).connect());
        await _insertRows(background, 'background');
        background.notifyUpdates({const TableUpdate('spike')});
        await background.close();
      }),
      _insertRows(main, 'ui'),
    ]);

    await notified.timeout(const Duration(seconds: 10));
    expect(await _count(main), 2 * _rowsPerWriter);
    await main.close();
    await server.shutdownAll();
  });

  test('two independent connections in two isolates never lose or double a write', () async {
    final path = file.path;
    final setupDb = AppDatabase(NativeDatabase(file, setup: configureConnection));
    await _createScratchTable(setupDb);
    await setupDb.close();

    Future<int> writer(String name) => Isolate.run(() async {
      final db = AppDatabase(NativeDatabase(File(path), setup: configureConnection));
      final retries = await _insertRowsRetrying(db, name);
      await db.close();
      return retries;
    });

    final retries = await Future.wait([writer('a'), writer('b')]);
    // Rare by design: the app uses one shared connection; this is the fallback path.
    expect(retries.fold(0, (a, b) => a + b), lessThan(50));

    final check = AppDatabase(NativeDatabase(file, setup: configureConnection));
    expect(await _count(check), 2 * _rowsPerWriter);
    final perWriter = await check
        .customSelect('SELECT writer, COUNT(*) AS c FROM spike GROUP BY writer ORDER BY writer')
        .get();
    expect(perWriter.map((r) => r.read<int>('c')), [_rowsPerWriter, _rowsPerWriter]);
    await check.close();
  });

  test('database files are per account and keyed by user id only', () {
    expect(
      databaseNameFor('0199B2C4-1A2B-7C3D-8E4F-5A6B7C8D9E0F'),
      'habit_0199b2c4-1a2b-7c3d-8e4f-5a6b7c8d9e0f',
    );
    expect(databaseNameFor('a'), isNot(databaseNameFor('b')));
    expect(() => databaseNameFor('../other'), throwsArgumentError);
    expect(() => databaseNameFor(''), throwsArgumentError);
  });
}
