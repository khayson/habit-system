import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/models/notice.dart';
import 'package:habit/services/notices_service.dart';

import '../support/app_harness.dart';
import '../support/fake_sync_server.dart';

/// A57: Today's carousel: a notice from the server, the reminder card, two tips; swipe to move,
/// a ✕ to dismiss, nothing when the server is out of reach but the built-in cards.
void main() {
  setUpAll(loadTestZones);

  /// A swipe ends in a short spring to the nearest card; taps wait until it stops.
  Future<void> snap(WidgetTester tester) async {
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('notice, reminder card and tips; a dot moves; a dismissal sticks', (tester) async {
    useTallPhone(tester);
    final folder = (await tester.runAsync(() => Directory.systemTemp.createTemp('carousel_')))!;
    final account = (await tester.runAsync(
      () => testAccount(FakeSyncServer(), noticesApi: _FakeNotices(), filesRoot: folder.path),
    ))!;
    await tester.runAsync(
      () => account.actions.createOneTapHabit(name: 'Stretch', category: 'health'),
    );
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(testApp(initial: '/today', account: account));
    await settle(tester);
    // The file read and the fetch are real I/O.
    await tester.runAsync(() => account.notices.refresh());
    await settle(tester);

    expect(find.text('From the Habit team'), findsOneWidget);
    expect(find.text('Weekly habits are here'), findsOneWidget);
    expect(find.bySemanticsLabel('Card 1 of 4'), findsOneWidget);

    // Swipe right to left: the reminder card; then back.
    await tester.drag(find.text('Weekly habits are here'), const Offset(-300, 0));
    await snap(tester);
    expect(find.bySemanticsLabel('Card 2 of 4'), findsOneWidget);
    expect(
      find.text('Set now').hitTestable(),
      findsOneWidget,
      reason: 'the reminder card is shown',
    );
    await tester.drag(find.text('Set now'), const Offset(300, 0));
    await snap(tester);
    expect(find.bySemanticsLabel('Card 1 of 4'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Dismiss Weekly habits are here'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await settle(tester);
    expect(find.text('Weekly habits are here'), findsNothing);
    expect(find.bySemanticsLabel('Card 1 of 3'), findsOneWidget);
    expect(account.notices.isDismissed('n1'), isTrue);

    handle.dispose();
    await tearDownApp(tester, account);
    await tester.runAsync(() => folder.delete(recursive: true));
  });

  testWidgets('offline: the built-in cards still show, with no error', (tester) async {
    useTallPhone(tester);
    final folder = (await tester.runAsync(() => Directory.systemTemp.createTemp('carousel_')))!;
    final account = (await tester.runAsync(
      () => testAccount(
        FakeSyncServer(),
        noticesApi: _FakeNotices(offline: true),
        filesRoot: folder.path,
      ),
    ))!;
    await tester.runAsync(
      () => account.actions.createOneTapHabit(name: 'Stretch', category: 'health'),
    );
    await tester.pumpWidget(testApp(initial: '/today', account: account));
    await settle(tester);
    await tester.runAsync(() => account.notices.refresh());
    await settle(tester);

    expect(find.text('From the Habit team'), findsNothing);
    expect(find.text('Set now'), findsOneWidget);
    expect(find.text('Tap the circle'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, account);
    await tester.runAsync(() => folder.delete(recursive: true));
  });
}

class _FakeNotices implements NoticesService {
  final bool offline;

  _FakeNotices({this.offline = false});

  @override
  Future<List<Notice>> fetch() async {
    if (offline) throw const SocketException('offline');
    return const [
      Notice(id: 'n1', title: 'Weekly habits are here', body: 'Pick the days you choose.'),
    ];
  }
}
