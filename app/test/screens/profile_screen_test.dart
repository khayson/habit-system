import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit/app/router.dart';
import 'package:habit/core/network/api_client.dart';
import 'package:habit/data/app_database.dart';
import 'package:habit/domain/calendar/local_date.dart';
import 'package:habit/providers/account_context.dart';
import 'package:habit/providers/session_provider.dart';
import 'package:habit/services/auth_service.dart';
import 'package:habit/services/countries.dart';
import 'package:habit/services/photo_picker.dart';
import 'package:habit/sync/outbox_states.dart';
import 'package:habit/widgets/avatar_view.dart';
import 'package:path/path.dart' as p;

import '../core/api_client_test.dart' show MemoryTokenStore;
import '../services/auth_service_test.dart' show MemoryAccountStore;
import '../support/app_harness.dart';
import '../support/fake_notification_scheduler.dart';
import '../support/fake_sync_server.dart';
import '../support/route_adapter.dart';

/// A fake picker: hands back a prepared square JPEG (or null: the user backed out).
class FakePhotoPicker implements PhotoPicker {
  String? path;
  final List<PhotoSource> asked = [];

  /// Thrown by the next pick (the platform refused, as a denied permission does).
  Object? failWith;

  FakePhotoPicker(this.path);

  @override
  Future<String?> pick(PhotoSource source, {required String cropTitle}) async {
    asked.add(source);
    final failure = failWith;
    if (failure != null) throw failure;
    return path;
  }
}

/// Screen 20 (A20): the avatar card, the rows as designed, the edit and photo sheets, the
/// Reminders sheet and sign out.
void main() {
  late List<int> photoBytes;

  setUpAll(() async {
    loadTestZones();
    TestWidgetsFlutterBinding.ensureInitialized();
    // Loaded once outside any test's fake clock, so every test reads the completed list.
    await Countries.load();
    photoBytes = await _squarePng();
  });

  late Directory temp;
  late FakePhotoPicker picker;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('habit_profile_');
    // A real, decodable image: a broken one fails to decode later, inside another test.
    final crop = File(p.join(temp.path, 'crop.png'))..writeAsBytesSync(photoBytes);
    picker = FakePhotoPicker(crop.path);
  });
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows may hold a file briefly; the OS cleans temp.
    }
  });

  Future<AccountContext> account(WidgetTester tester, FakeSyncServer server) async {
    useTallPhone(tester);
    return (await tester.runAsync(() => testAccount(server)))!;
  }

  Future<void> open(WidgetTester tester, AccountContext account) async {
    await tester.pumpWidget(testApp(initial: Routes.today, account: account, photoPicker: picker));
    await settle(tester);
    await tester.tap(find.text('Profile'));
    // Three watch-queries and the permission read: give them a few more rounds.
    await settle(tester, rounds: 16);
  }

  /// Settles until [finder] finds something (real I/O, drift) or [maxRounds] pass.
  Future<void> settleUntil(WidgetTester tester, Finder finder, {int maxRounds = 60}) async {
    for (var i = 0; i < maxRounds && finder.evaluate().isEmpty; i++) {
      await settle(tester, rounds: 1);
    }
  }

  Future<List<OutboxRow>> outbox(WidgetTester tester, AccountContext account) async =>
      (await tester.runAsync(() => account.session.db.select(account.session.db.outbox).get()))!;

  testWidgets('the Profile tab opens 20 as designed, without the later rows', (tester) async {
    final a = await account(tester, FakeSyncServer());
    await open(tester, a);

    expect(find.text('Your space'), findsOneWidget);
    expect(find.text('Preferences that follow your life.'), findsOneWidget);
    final avatar = tester.getSemantics(find.byType(AvatarView));
    expect((avatar.label, avatar.hint), ('Profile photo of Maya', 'Change the profile photo'));
    expect(avatar.flagsCollection.isButton, isTrue);
    expect(find.bySemanticsLabel('Profile photo of Maya'), findsOneWidget);
    expect(find.text('M'), findsOneWidget, reason: 'initials without a photo');
    expect(find.text('Add your city and country'), findsOneWidget);
    expect(find.text('Timezone'), findsOneWidget);
    // I2: the city as screen 04 names it; the IANA id is for assistive technology only.
    expect(find.text('Los Angeles'), findsOneWidget);
    expect(find.text('America/Los_Angeles'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('America/Los_Angeles')), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Signed in as maya@example.com'), findsOneWidget);
    expect(find.text('Privacy and export'), findsNothing, reason: '21 arrives in Phase 6');
    expect(find.text('Archived habits'), findsNothing, reason: '22 arrives in Phase 4');
    expect(find.text('Terms'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  group('the level line (design 20, A44)', () {
    Future<void> confirm(WidgetTester tester, AccountContext a) => tester.runAsync(
      () => a.session.db
          .into(a.session.db.rewardState)
          .insert(
            RewardStateCompanion.insert(
              id: a.session.userId,
              xp: const Value(1250),
              level: const Value(13),
              version: 2,
            ),
          ),
    );

    testWidgets('place, level and XP as designed', (tester) async {
      final a = await account(tester, FakeSyncServer());
      await tester.runAsync(
        () => a.writer.updateProfile(name: 'Maya Chen', city: 'Portland', countryCode: null),
      );
      await confirm(tester, a);
      await open(tester, a);

      expect(find.text('Portland · Level 13 · 1,250 XP'), findsOneWidget);
      await tearDownApp(tester, a);
    });

    testWidgets('without a place: level and XP only', (tester) async {
      final a = await account(tester, FakeSyncServer());
      await confirm(tester, a);
      await open(tester, a);

      expect(find.text('Level 13 · 1,250 XP'), findsOneWidget);
      expect(find.text('Add your city and country'), findsNothing);
      await tearDownApp(tester, a);
    });

    testWidgets('without confirmed numbers: the place alone', (tester) async {
      final a = await account(tester, FakeSyncServer());
      await tester.runAsync(
        () => a.writer.updateProfile(name: 'Maya Chen', city: 'Portland', countryCode: null),
      );
      await open(tester, a);

      expect(find.text('Portland'), findsOneWidget);
      expect(find.textContaining('Level'), findsNothing);
      await tearDownApp(tester, a);
    });
  });

  testWidgets('edit: Save waits for a change; the country is searched; one profile.update', (
    tester,
  ) async {
    final a = await account(tester, FakeSyncServer());
    await open(tester, a);

    await tester.tap(find.text('Edit profile'));
    await settle(tester);
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull, reason: 'unchanged');

    await tester.enterText(find.widgetWithText(TextField, 'City'), 'Accra');
    await tester.tap(find.text('No country'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Search countries'), 'ghan');
    await settle(tester);
    await tester.tap(find.text('Ghana'));
    await settle(tester);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await settle(tester);

    final rows = (await outbox(tester, a)).where((r) => r.operation == 'profile.update');
    expect(rows, hasLength(1));
    expect(find.text('Accra, Ghana'), findsOneWidget, reason: 'shown at once');
    expect(find.text('Waiting to sync'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  testWidgets('an empty name cannot be saved', (tester) async {
    final a = await account(tester, FakeSyncServer());
    await open(tester, a);
    await tester.tap(find.text('Edit profile'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Maya'), '  ');
    await settle(tester);

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed,
      isNull,
    );
    await tearDownApp(tester, a);
  });

  testWidgets('photo: choose shows it at once and queues it; remove only when there is one', (
    tester,
  ) async {
    final a = await account(tester, FakeSyncServer());
    await open(tester, a);

    await tester.tap(find.bySemanticsLabel('Profile photo of Maya'));
    await settle(tester);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing, reason: 'no photo yet');

    await tester.tap(find.text('Choose photo'));
    // Copying the photo is real file I/O: wait for it, not for a fixed number of frames.
    await settleUntil(tester, find.byType(Image));
    expect(picker.asked, [PhotoSource.gallery]);
    expect(find.byType(Image), findsOneWidget, reason: 'the photo, not initials');
    expect(find.text('Waiting to upload'), findsOneWidget);
    final uploads = (await tester.runAsync(
      () => a.session.db.select(a.session.db.pendingUploads).get(),
    ))!;
    expect(uploads.single.op, 'put');

    await tester.tap(find.bySemanticsLabel('Profile photo of Maya'));
    await settle(tester);
    await tester.tap(find.text('Remove photo'));
    await settleUntil(tester, find.text('M'));
    expect(find.text('M'), findsOneWidget);
    await tearDownApp(tester, a);
  });

  testWidgets('backing out of the picker changes nothing', (tester) async {
    picker.path = null;
    final a = await account(tester, FakeSyncServer());
    await open(tester, a);

    await tester.tap(find.bySemanticsLabel('Profile photo of Maya'));
    await settle(tester);
    await tester.tap(find.text('Take photo'));
    await settle(tester);

    expect(picker.asked, [PhotoSource.camera]);
    expect(find.text('M'), findsOneWidget);
    expect(
      (await tester.runAsync(() => a.session.db.select(a.session.db.pendingUploads).get()))!,
      isEmpty,
    );
    await tearDownApp(tester, a);
  });

  testWidgets('Reminders: habits with reminders open 11; the hide-names switch saves', (
    tester,
  ) async {
    final a = await account(tester, FakeSyncServer());
    await tester.runAsync(() async {
      // Through the writer: a habit with a reminder is the setup, and the actions' debounced
      // sync (a real-clock timer) could fire during teardown under load.
      final habit = await a.writer.createHabitUnchecked(
        name: 'Water',
        type: 'binary',
        target: 1,
        category: 'health',
        startLocalDate: LocalDate.parse('2026-05-28'),
      );
      await a.writer.createReminder(habitId: habit, localTime: '08:00', daysOfWeek: [1, 2, 3]);
    });
    (a.notifications as FakeNotificationScheduler).grantOnRequest = true;
    await open(tester, a);

    expect(find.textContaining('1 reminder · '), findsOneWidget);
    await tester.tap(find.text('Reminders'));
    await settle(tester);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Hide habit names in notifications'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await settle(tester, rounds: 16);
    // Read back from the database: close the sheet and open it again.
    await tester.tapAt(const Offset(200, 40));
    await settle(tester);
    await tester.tap(find.text('Reminders'));
    await settle(tester, rounds: 16);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.text('Water'));
    await settle(tester, rounds: 16);
    expect(find.text('Gentle reminders'), findsOneWidget, reason: 'live screen 11');
    await tearDownApp(tester, a);
  });

  testWidgets('no overflow at text scale 2.0, with an edit and a photo waiting', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final a = await account(tester, FakeSyncServer());
    await tester.runAsync(() async {
      await a.writer.updateProfile(name: 'Maya Chen', city: 'Accra', countryCode: 'GH');
      await a.photos.choose(picker.path!);
    });
    await open(tester, a);

    expect(tester.takeException(), isNull);
    expect(find.text('Waiting to sync'), findsOneWidget);
    expect(find.text('Waiting to upload'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sign out'), 300);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, a);
  });

  group('R1: failures show one neutral line and change nothing', () {
    Future<void> failInserts(WidgetTester tester, AccountContext a, String table) =>
        tester.runAsync(
          () => a.session.db.customStatement(
            'CREATE TRIGGER fail_$table BEFORE INSERT ON $table '
            "BEGIN SELECT RAISE(ABORT, 'storage unavailable'); END",
          ),
        );

    Future<int> queued(WidgetTester tester, AccountContext a) async =>
        (await tester.runAsync(() async {
          final db = a.session.db;
          return (await db.select(db.outbox).get()).length +
              (await db.select(db.pendingUploads).get()).length;
        }))!;

    testWidgets('the picker fails (no access)', (tester) async {
      picker.failWith = PlatformException(code: 'photo_access_denied');
      final a = await account(tester, FakeSyncServer());
      await open(tester, a);

      await tester.tap(find.bySemanticsLabel('Profile photo of Maya'));
      await settle(tester);
      await tester.tap(find.text('Choose photo'));
      await settleUntil(tester, find.textContaining("couldn't open your photos"));

      expect(
        find.text("We couldn't open your photos. You can allow access in your device settings."),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(await queued(tester, a), 0);
      await tearDownApp(tester, a);
    });

    testWidgets('the photo cannot be stored', (tester) async {
      picker.path = p.join(temp.path, 'gone.jpg'); // the cropper's file has vanished
      final a = await account(tester, FakeSyncServer());
      await open(tester, a);

      await tester.tap(find.bySemanticsLabel('Profile photo of Maya'));
      await settle(tester);
      await tester.tap(find.text('Choose photo'));
      await settleUntil(tester, find.textContaining("couldn't be added"));

      expect(find.text("That photo couldn't be added. Try another."), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(await queued(tester, a), 0);
      expect(find.text('M'), findsOneWidget);
      await tearDownApp(tester, a);
    });

    testWidgets('saving the profile fails: the input stays, Save works again', (tester) async {
      final a = await account(tester, FakeSyncServer());
      await failInserts(tester, a, 'outbox');
      await open(tester, a);
      await tester.tap(find.text('Edit profile'));
      await settle(tester);

      await tester.enterText(find.widgetWithText(TextField, 'City'), 'Accra');
      await tester.pump(); // Save is enabled on the next frame
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settleUntil(tester, find.text("We couldn't save that. Try again."));

      expect(find.text("We couldn't save that. Try again."), findsOneWidget);
      expect(find.text('Accra'), findsOneWidget, reason: 'the input is kept, the sheet open');
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed,
        isNotNull,
        reason: 'no longer busy',
      );
      expect(tester.takeException(), isNull);
      expect(await queued(tester, a), 0);
      await tearDownApp(tester, a);
    });

    testWidgets('saving the hide-names switch fails: it goes back', (tester) async {
      final a = await account(tester, FakeSyncServer());
      await failInserts(tester, a, 'local_settings');
      await open(tester, a);
      await tester.tap(find.text('Reminders'));
      await settle(tester, rounds: 16);

      await tester.tap(find.byType(Switch));
      await settleUntil(tester, find.text("We couldn't save that. Try again."));

      expect(find.text("We couldn't save that. Try again."), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse, reason: 'back');
      expect(tester.takeException(), isNull);
      await tearDownApp(tester, a);
    });
  });

  testWidgets('P2: when replacing scheduled reminders fails, the switch shows what is stored', (
    tester,
  ) async {
    final a = await account(tester, FakeSyncServer());
    await tester.runAsync(() async {
      // Through the writer: a habit with a reminder is the setup, and the actions' debounced
      // sync (a real-clock timer) could fire during teardown under load.
      final habit = await a.writer.createHabitUnchecked(
        name: 'Water',
        type: 'binary',
        target: 1,
        category: 'health',
        startLocalDate: LocalDate.parse('2026-05-28'),
      );
      await a.writer.createReminder(
        habitId: habit,
        localTime: '20:00',
        daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      );
      await a.reminders.replan();
    });
    (a.notifications as FakeNotificationScheduler).failCancel = true;
    await open(tester, a);
    await tester.tap(find.text('Reminders'));
    await settle(tester, rounds: 16);

    await tester.tap(find.byType(Switch));
    await settleUntil(tester, find.text("We couldn't save that. Try again."));

    expect(find.text("We couldn't save that. Try again."), findsOneWidget);
    // The setting was saved before the replan failed: the switch must not claim otherwise.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(tester.takeException(), isNull);
    await tearDownApp(tester, a);
  });

  group('sign out', () {
    late RouteAdapter http;
    late SessionProvider session;
    late List<AppDatabase> opened;

    setUp(() {
      http = RouteAdapter()
        ..on('POST /auth/login', Reply(200, sessionBody()))
        ..on('POST /auth/logout', const Reply(204, null));
      opened = [];
      final server = FakeSyncServer();
      final tokens = MemoryTokenStore();
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = http;
      final auth = AuthService(
        ApiClient.withDio(dio, tokens),
        tokens,
        MemoryAccountStore(),
        // File-backed: sign-out closes the database, and the test reopens the file after.
        openDatabase: (_) {
          final db = AppDatabase(
            DatabaseConnection(
              NativeDatabase(File(p.join(temp.path, 'account.sqlite'))),
              closeStreamsSynchronously: true,
            ),
          );
          opened.add(db);
          return db;
        },
        clock: () => testNow,
      );
      session = SessionProvider(
        auth,
        buildAccount: (s) => AccountContext(
          session: s,
          transport: server,
          refreshIfStale: () async {},
          notifications: FakeNotificationScheduler(),
          filesRoot: temp.path,
          clock: () => testNow,
        ),
      );
    });

    Future<void> signedIn(WidgetTester tester) async {
      useTallPhone(tester);
      await tester.runAsync(() async {
        await session.signIn(email: 'maya@example.com', password: 'correct horse battery');
        session.completeSetup();
      });
      await tester.pumpWidget(testApp(initial: Routes.profile, session: session));
      await settle(tester);
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      session.account?.dispose();
      await tester.runAsync(() async {
        for (final db in opened) {
          await db.close();
        }
      });
    }

    testWidgets('with nothing unsynced it signs out at once', (tester) async {
      await signedIn(tester);
      await tester.scrollUntilVisible(find.text('Sign out'), 200);

      await tester.tap(find.text('Sign out'));
      await settle(tester);

      expect(find.text('Sign out?'), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget, reason: 'back on sign-in (02)');
      expect(http.sent('POST /auth/logout'), hasLength(1));
      await finish(tester);
    });

    testWidgets('with unsynced changes it asks first, in plain words, and keeps them', (
      tester,
    ) async {
      await signedIn(tester);
      await tester.runAsync(
        () => session.account!.writer.updateProfile(name: 'Maya C', city: null, countryCode: null),
      );
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Sign out'), 200);

      await tester.tap(find.text('Sign out'));
      await settle(tester);
      expect(
        find.text(
          "1 change hasn't synced yet. It stays saved on this phone and uploads the next time "
          'you sign in here.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Your space'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await settle(tester);
      await tester.tap(find.text('Sign out').last);
      await settle(tester);
      expect(find.text('Welcome back'), findsOneWidget);
      final kept = (await tester.runAsync(() async {
        final reopened = AppDatabase(NativeDatabase(File(p.join(temp.path, 'account.sqlite'))));
        opened.add(reopened);
        return reopened.select(reopened.outbox).get();
      }))!;
      expect(kept.map((r) => (r.operation, r.state)), [
        ('profile.update', OutboxState.pending),
      ], reason: 'never deleted');
      await finish(tester);
    });
  });
}

Map<String, Object?> sessionBody() => envelope({
  'user': {...FakeSyncServer().user, 'id': 'user-1', 'version': 1},
  'token': 'tok-1',
  'token_type': 'Bearer',
});

/// An 8 x 8 PNG drawn with dart:ui, for the picker to hand back.
Future<List<int>> _squarePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
      .drawRect(const ui.Rect.fromLTWH(0, 0, 8, 8), ui.Paint()..color = const ui.Color(0xFF2E7D4F));
  final image = await recorder.endRecording().toImage(8, 8);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}
