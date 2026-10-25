import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/core/exceptions/app_exception.dart';
import 'package:habit/core/file_sharer.dart';
import 'package:habit/models/export_job.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/screens/privacy_screen.dart';
import 'package:habit/services/export_service.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// Phase 6.1 (A48): screens 21, 29 and 30. The service and the share sheet are fakes.
void main() {
  setUpAll(loadTestZones);
  setUp(resetPrivacyFormatForTest);

  /// A time reads with a narrow no-break space before AM.
  Finder timeText(String t) => find.byWidgetPredicate(
    (w) => w is Text && w.data?.replaceAll('\u202f', ' ') == t,
    description: 'text "$t"',
  );

  ExportJob job(ExportStatus status, {String id = 'j1', String format = 'json'}) => ExportJob(
    id: id,
    format: format,
    status: status,
    requestedAt: DateTime.utc(2026, 5, 28, 17, 22),
    expiresAt: status == ExportStatus.ready ? DateTime.utc(2026, 5, 29, 17, 22) : null,
    downloadUrl: status == ExportStatus.ready ? 'https://api.test/exports/$id/download' : null,
    errorCode: status == ExportStatus.failed ? 'export_failed' : null,
  );

  Future<AccountContext> account(WidgetTester tester, FakeExports api) async {
    useTallPhone(tester);
    return (await tester.runAsync(() => testAccount(FakeSyncServer(), exportsApi: api)))!;
  }

  Future<void> open(
    WidgetTester tester,
    AccountContext a, {
    String at = '/privacy',
    FakeSharer? sharer,
  }) async {
    await tester.pumpWidget(testApp(initial: at, account: a, fileSharer: sharer ?? FakeSharer()));
    await settle(tester);
  }

  for (final (status, word) in [
    (ExportStatus.queued, 'queued'),
    (ExportStatus.running, 'preparing'),
    (ExportStatus.ready, 'ready'),
    (ExportStatus.failed, 'failed'),
    (ExportStatus.expired, 'expired'),
  ]) {
    testWidgets('21 shows a $word latest export in words', (tester) async {
      final a = await account(tester, FakeExports()..jobs = [job(status)]);
      await open(tester, a);

      for (final t in [
        'Your data, yours',
        'Export habit history whenever you need it.',
        'JSON backup',
        'CSV history',
        'Included in your export',
        'Habits, logs, rewards, freeze history',
        'Latest export · $word',
        'JSON · requested 28 May',
        'Request new export',
        'Exports are private. Download links are temporary.',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      final ready = status == ExportStatus.ready;
      expect(
        find.text('Private download expires after 24 hours.'),
        ready ? findsOneWidget : findsNothing,
      );
      expect(find.text('Download latest export'), ready ? findsOneWidget : findsNothing);
      expect(find.text('Restore from a JSON backup'), findsNothing, reason: '6.3');
      expect(find.text('Delete account'), findsOneWidget, reason: '28, Phase 6.2');
      // 6.1 review L1: 21 draws the bottom bar with Profile selected.
      expect(find.text('Today'), findsOneWidget, reason: 'the bottom bar, as designed');
      expect(tester.getSemantics(find.text('Profile')).flagsCollection.isSelected, Tristate.isTrue);
      await tearDownApp(tester, a);
    });
  }

  testWidgets('21 says how many changes wait to sync, and up to date once none do', (tester) async {
    final a = await account(tester, FakeExports());
    await open(tester, a);
    expect(find.text('Cloud history is up to date'), findsOneWidget);

    await tester.runAsync(() async {
      final habit = await a.actions.createOneTapHabit(name: 'Stretch', category: 'health');
      await a.writer.setLogValue(habitId: habit, value: 1);
    });
    await settle(tester);

    expect(find.text('2 changes waiting to sync'), findsOneWidget);
    expect(find.text('They reach a server export only after syncing.'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  testWidgets('21 lists the selected format\'s latest export', (tester) async {
    final a = await account(
      tester,
      FakeExports()
        ..jobs = [job(ExportStatus.ready, id: 'c1', format: 'csv'), job(ExportStatus.failed)],
    );
    await open(tester, a);
    expect(find.text('Latest export · failed'), findsOneWidget);

    await tester.tap(find.text('CSV history'));
    await settle(tester);
    expect(find.text('Latest export · ready'), findsOneWidget);
    expect(find.text('CSV · requested 28 May'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  testWidgets('request opens 29, which polls to ready and downloads through the share sheet', (
    tester,
  ) async {
    final api = FakeExports()..created = job(ExportStatus.queued, id: 'n1');
    final sharer = FakeSharer();
    final a = await account(tester, api);
    await open(tester, a, sharer: sharer);

    await tester.tap(find.text('Request new export'));
    await settle(tester);

    for (final t in [
      'Preparing your export',
      'Your history will be ready as a private download.',
      'Queued securely',
      'Your export includes',
      'You can leave this screen. The export status stays available in Privacy and export.',
      'Back to privacy and export',
      'Download is available only after status is Ready.',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(
      timeText('JSON backup requested today at 10:22 AM. This may take a little time.'),
      findsOneWidget,
    );
    expect(api.requested, ['json']);
    expect(find.text('Today'), findsNothing, reason: '29 draws no bottom bar');

    api.byId['n1'] = job(ExportStatus.running, id: 'n1');
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.text('Download latest export'), findsNothing);
    api.byId['n1'] = job(ExportStatus.ready, id: 'n1');
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.text('Ready to download'), findsOneWidget);

    await tester.tap(find.text('Download latest export'));
    await settle(tester);
    expect(api.downloaded, ['n1']);
    expect(sharer.shared.single, endsWith('habit-export.zip'));
    expect(File(sharer.shared.single).existsSync(), isFalse, reason: 'the temporary file is gone');
    await tearDownApp(tester, a);
  });

  testWidgets('a failed job shows 30; Retry asks again and returns to 29', (tester) async {
    final api = FakeExports()
      ..byId['f1'] = job(ExportStatus.failed, id: 'f1')
      ..created = job(ExportStatus.queued, id: 'r1');
    final a = await account(tester, api);
    await open(tester, a, at: '/privacy/exports/f1');

    for (final t in [
      "Let's try that again",
      'Your habits and history are unchanged.',
      'The export did not finish',
      'No data was lost. Retry the job when a connection is available.',
      'JSON backup · failed',
      'Request from today at 10:22 AM',
      'Retry export',
      'Back to privacy and export',
    ]) {
      expect(timeText(t), findsOneWidget, reason: t);
    }

    await tester.tap(find.text('Retry export'));
    await settle(tester);
    expect(api.requested, ['json']);
    expect(find.text('Preparing your export'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  testWidgets('29 stops asking after two minutes', (tester) async {
    final api = FakeExports()..byId['q1'] = job(ExportStatus.queued, id: 'q1');
    final a = await account(tester, api);
    await open(tester, a, at: '/privacy/exports/q1');
    final before = api.gets;

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
    await settle(tester);

    expect(api.gets - before, lessThanOrEqualTo(24));
    await tearDownApp(tester, a);
  });

  testWidgets('a failed download says so in words and keeps the screen', (tester) async {
    final api = FakeExports()
      ..jobs = [job(ExportStatus.ready)]
      ..failDownload = true;
    final a = await account(tester, api);
    await open(tester, a);

    await tester.tap(find.text('Download latest export'));
    await settle(tester);

    expect(find.text("The download did not finish. Try again when you're online."), findsOneWidget);
    expect(find.text('Download latest export'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  // 6.1 review L4.
  testWidgets('an expired download reloads the list and says so', (tester) async {
    final api = FakeExports()
      ..jobs = [job(ExportStatus.ready)]
      ..expireOnDownload = true;
    final a = await account(tester, api);
    await open(tester, a);

    await tester.tap(find.text('Download latest export'));
    await settle(tester);

    expect(find.text('This download has expired. Request a new export.'), findsOneWidget);
    expect(find.text('Latest export · expired'), findsOneWidget, reason: 'the list was reloaded');
    expect(find.text('Download latest export'), findsNothing);
    expect(find.text('Request new export'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  testWidgets('Profile opens 21', (tester) async {
    final a = await account(tester, FakeExports());
    await tester.pumpWidget(testApp(initial: '/profile', account: a, fileSharer: FakeSharer()));
    await settle(tester, rounds: 16);

    await tester.scrollUntilVisible(find.text('Privacy and export'), 200);
    await tester.tap(find.text('Privacy and export'));
    await settle(tester);

    expect(find.text('Your data, yours'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  for (final at in ['/privacy', '/privacy/exports/j1']) {
    testWidgets('text scale 2.0 keeps $at readable', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final a = await account(
        tester,
        FakeExports()
          ..jobs = [job(ExportStatus.ready)]
          ..byId['j1'] = job(ExportStatus.queued),
      );
      await open(tester, a, at: at);

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.textContaining(
          at == '/privacy' ? 'Exports are private' : 'Download is available only',
        ),
        300,
      );
      expect(tester.takeException(), isNull);
      await tearDownApp(tester, a);
    });
  }
}

class FakeSharer implements FileSharer {
  final List<String> shared = [];

  @override
  Future<Directory> temporaryRoot() async => Directory.systemTemp;

  @override
  Future<void> share(String path) async => shared.add(path);
}

class FakeExports implements ExportService {
  List<ExportJob> jobs = [];
  final Map<String, ExportJob> byId = {};
  ExportJob? created;
  final List<String> requested = [];
  final List<String> downloaded = [];
  bool failDownload = false;

  /// The server answers 410 export_expired, and the job reads expired from then on.
  bool expireOnDownload = false;
  int gets = 0;

  @override
  Future<List<ExportJob>> list() async => jobs;

  @override
  Future<ExportJob> get(String id) async {
    gets++;
    return byId[id] ?? jobs.firstWhere((j) => j.id == id);
  }

  @override
  Future<ExportJob> request(String format) async {
    requested.add(format);
    final job = created!;
    byId[job.id] = job;
    return job;
  }

  @override
  Future<File> download(ExportJob job, String folder) async {
    if (expireOnDownload) {
      jobs = [for (final j in jobs) j.id == job.id ? _expired(j) : j];
      throw const AppException(
        kind: AppErrorKind.api,
        code: 'export_expired',
        message: 'This download has expired. Request a new export.',
        statusCode: 410,
      );
    }
    if (failDownload) {
      throw const AppException(kind: AppErrorKind.network, code: 'network', message: 'x');
    }
    downloaded.add(job.id);
    return File('$folder/habit-export.zip')..writeAsBytesSync([80, 75]);
  }

  static ExportJob _expired(ExportJob j) => ExportJob(
    id: j.id,
    format: j.format,
    status: ExportStatus.expired,
    requestedAt: j.requestedAt,
  );
}
