import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/database_opener.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uuid/uuid.dart';

/// A23 spike, device side: the production opener (`shareAcrossIsolates` via IsolateNameServer)
/// used from the UI isolate and from a background isolate at the same time, on Android.
/// Runs in a background isolate, like workmanager or a notification action would. Top-level so
/// the isolate captures nothing from the UI side.
Future<void> _backgroundWriter(RootIsolateToken token, String account) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  // Same function as the UI isolate; it finds the running server by name.
  final background = openAccountDatabase(account);
  for (var i = 0; i < 200; i++) {
    await background.customInsert(
      'INSERT INTO spike (writer) VALUES (?)',
      variables: [const Variable('background')],
    );
  }
  background.notifyUpdates({const TableUpdate('spike')});
  await background.close();
}

/// Builds the isolate closure in its own scope so it captures only the token and account id.
Future<void> _inBackgroundIsolate(RootIsolateToken token, String account) =>
    Isolate.run(() => _backgroundWriter(token, account));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI and background isolates share one account database', (tester) async {
    final account = const Uuid().v7();
    final ui = openAccountDatabase(account);
    await ui.customStatement(
      'CREATE TABLE IF NOT EXISTS spike (id INTEGER PRIMARY KEY, writer TEXT NOT NULL)',
    );
    final notified = ui.tableUpdates(const TableUpdateQuery.onTableName('spike')).first;

    final token = RootIsolateToken.instance!;
    await Future.wait([
      _inBackgroundIsolate(token, account),
      () async {
        for (var i = 0; i < 200; i++) {
          await ui.customInsert(
            'INSERT INTO spike (writer) VALUES (?)',
            variables: [const Variable('ui')],
          );
        }
      }(),
    ]);

    await notified.timeout(const Duration(seconds: 10));
    final count = await ui.customSelect('SELECT COUNT(*) AS c FROM spike').getSingle();
    expect(count.read<int>('c'), 400);

    final journal = await ui.customSelect('PRAGMA journal_mode').getSingle();
    expect(journal.data.values.single, 'wal');
    final synchronous = await ui.customSelect('PRAGMA synchronous').getSingle();
    expect(synchronous.data.values.single, 2, reason: 'synchronous = FULL');
    await ui.close();
  });
}
