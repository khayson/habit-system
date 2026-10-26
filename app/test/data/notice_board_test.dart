import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit/data/notice_board.dart';
import 'package:habit/models/notice.dart';

import '../support/contract_fixtures.dart';

/// A57: the carousel's notices: decoded tolerantly, fetched at most every 15 minutes, cached and
/// dismissed per account in the account's folder.
void main() {
  late Directory folder;
  var now = DateTime.utc(2026, 10, 26, 10);
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('notices_');
    now = DateTime.utc(2026, 10, 26, 10);
  });
  tearDown(() => folder.delete(recursive: true));

  test('the fixture decodes; unknown fields and broken items never crash', () {
    final data = (contractFixture('notices/notices_response.json')['body'] as Map)['data'] as List;
    final notices = [for (final n in data) ?Notice.tryParse(n)];
    expect(notices.map((n) => n.title), ['Weekly habits are here', 'Thank you for testing']);
    expect(notices.last.endsAt, isNull);
    expect(Notice.tryParse({'id': 'x', 'title': 't', 'body': 'b', 'colour': 'red'})?.title, 't');
    expect(Notice.tryParse({'id': 'x', 'title': 3, 'body': 'b'}), isNull);
    expect(Notice.tryParse('nope'), isNull);
  });

  test('fetches at most every 15 minutes; a failure keeps the cache', () async {
    var calls = 0;
    var fail = false;
    final board = NoticeBoard(
      folder: folder.path,
      clock: () => now,
      fetch: () async {
        calls++;
        if (fail) throw const SocketException('offline');
        return [const Notice(id: 'a', title: 'Hello', body: 'Body.')];
      },
    );
    await board.refresh();
    await board.refresh();
    expect(calls, 1);
    expect(board.visible.single.title, 'Hello');

    now = now.add(const Duration(minutes: 16));
    fail = true;
    await board.refresh();
    expect(calls, 2);
    expect(board.visible.single.title, 'Hello', reason: 'offline keeps what was fetched');
  });

  test('cache and dismissals survive a restart; an ended notice is hidden', () async {
    final first = NoticeBoard(
      folder: folder.path,
      clock: () => now,
      fetch: () async => [
        Notice(id: 'a', title: 'Ends soon', body: 'B.', endsAt: now.add(const Duration(hours: 1))),
        const Notice(id: 'b', title: 'Stays', body: 'B.'),
      ],
    );
    await first.refresh();
    await first.dismiss('tip:circle');

    final again = NoticeBoard(folder: folder.path, clock: () => now);
    await again.refresh();
    expect(again.loaded, isTrue);
    expect(again.visible.map((n) => n.id), ['a', 'b']);
    expect(again.isDismissed('tip:circle'), isTrue);

    now = now.add(const Duration(hours: 2));
    expect(again.visible.map((n) => n.id), ['b']);
    await again.dismiss('b');
    expect(again.visible, isEmpty);
  });
}
