import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/data/database_opener.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// K2 (3.2b review): the busy retry in AppDatabase.transaction, as errors actually arrive.
/// openAccountDatabase keeps the database in a drift isolate. Errors cross it as a
/// DriftRemoteException: with the SqliteException itself when the ports can carry objects
/// (the same Flutter engine), or as its text when drift serializes (another engine, such as
/// workmanager's background engine). Both are tested; a drift upgrade changing either fails here.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('habit_busy_');
    file = File(p.join(dir.path, 'habit_busy.sqlite'));
    final setup = AppDatabase(NativeDatabase(file, setup: configureConnection));
    await setup.customStatement('CREATE TABLE IF NOT EXISTS probe (id INTEGER PRIMARY KEY)');
    await setup.close();
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold the WAL files briefly; the OS cleans temp.
    }
  });

  /// The database in a drift isolate that does not wait on busy_timeout, reached with or
  /// without serialization.
  Future<AppDatabase> impatientInIsolate({required bool serialize}) async {
    final path = file.path;
    final isolate = await DriftIsolate.spawn(
      () => NativeDatabase(
        File(path),
        setup: (db) {
          configureConnection(db);
          db.execute('PRAGMA busy_timeout = 0');
        },
      ),
    );
    final connection = await DriftIsolate.fromConnectPort(
      isolate.connectPort,
      serialize: serialize,
    ).connect(singleClientMode: true);
    return AppDatabase(connection);
  }

  Future<int> rows(AppDatabase db) async =>
      (await db.customSelect('SELECT count(*) AS c FROM probe').getSingle()).read<int>('c');

  Future<Object?> busyError(AppDatabase db) async {
    final holder = sqlite.sqlite3.open(file.path)..execute('BEGIN IMMEDIATE');
    try {
      await db.customStatement('INSERT INTO probe DEFAULT VALUES');
      return null;
    } on Object catch (e) {
      return e;
    } finally {
      holder
        ..execute('COMMIT')
        ..close();
    }
  }

  test('same engine: a DriftRemoteException carrying the SqliteException (code 5)', () async {
    final db = await impatientInIsolate(serialize: false);
    await rows(db);
    final error = await busyError(db);
    expect(error, isA<DriftRemoteException>());
    final cause = (error! as DriftRemoteException).remoteCause;
    expect(cause, isA<sqlite.SqliteException>());
    expect((cause as sqlite.SqliteException).resultCode & 0xff, 5);
    await db.close();
  });

  test('another engine (serialized): a DriftRemoteException whose cause is the text', () async {
    final db = await impatientInIsolate(serialize: true);
    await rows(db);
    final error = await busyError(db);
    expect(error, isA<DriftRemoteException>());
    final cause = (error! as DriftRemoteException).remoteCause;
    expect(cause, isA<String>());
    expect(cause as String, contains('database is locked'));
    await db.close();
  });

  for (final serialize in [false, true]) {
    test('a BEGIN refused through the isolate is retried (serialize: $serialize)', () async {
      final db = await impatientInIsolate(serialize: serialize);
      await rows(db);
      final holder = sqlite.sqlite3.open(file.path)..execute('BEGIN IMMEDIATE');
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        holder
          ..execute('COMMIT')
          ..close();
      });

      await db.transaction(() => db.customStatement('INSERT INTO probe DEFAULT VALUES'));

      expect(await rows(db), 1);
      await db.close();
    });
  }

  test('a BUSY thrown inside the body surfaces, and the body ran once', () async {
    final db = AppDatabase(NativeDatabase(file, setup: configureConnection));
    var runs = 0;
    await expectLater(
      db.transaction(() async {
        runs++;
        await db.customStatement('INSERT INTO probe DEFAULT VALUES');
        throw sqlite.SqliteException(extendedResultCode: 5, message: 'database is locked');
      }),
      throwsA(isA<sqlite.SqliteException>()),
    );
    expect(runs, 1);
    expect(await rows(db), 0, reason: 'the body rolled back');
    await db.close();
  });
}
