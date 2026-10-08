import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/calendar/timezone_timeline.dart';
import '../sync/outbox_states.dart';
import 'account_calendar.dart';
import 'app_database.dart';

/// Per-device settings in local_settings (screen 04).
/// ASSUMPTION(A3.2-follow-device): "Follow device time zone" is a setting of this device until
/// it moves to the server with profile.update in Phase 3b.
class DeviceSettings {
  static const followDevice = 'follow_device_timezone';
  static const _notNowPrefix = 'timezone_not_now:';

  final AppDatabase db;

  const DeviceSettings(this.db);

  Future<String?> read(String key) async => (await (db.select(
    db.localSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  /// One transaction per write, like every other local write, so watchers see it at once.
  Future<void> write(String key, String value) => db.transaction(
    () => db
        .into(db.localSettings)
        .insertOnConflictUpdate(LocalSettingsCompanion.insert(key: key, value: value)),
  );

  Future<void> setFollowDevice(bool on) => write(followDevice, on ? '1' : '0');

  /// "Not now" is remembered per detected zone: a later move to another zone asks again.
  Future<void> notNow(String zone) => write('$_notNowPrefix$zone', '1');

  /// The settings rows themselves are selected, so a settings write always changes the result
  /// and re-runs the status (a constant query is not re-delivered for every write).
  Stream<TimezoneStatus?> watch(DateTime Function() deviceNow) => db
      .customSelect(
        "SELECT key || '=' || value AS kv FROM local_settings",
        readsFrom: {db.localSettings, db.outbox, db.calendarEntries, db.syncState},
      )
      .watch()
      .asyncMap((_) => status(deviceNow()));

  Future<TimezoneStatus?> status(DateTime deviceNow) async {
    final calendar = await AccountCalendar.load(db, deviceNow: deviceNow);
    if (calendar == null) return null;
    final settings = {for (final s in await db.select(db.localSettings).get()) s.key: s.value};
    final queued =
        await (db.select(db.outbox)
              ..where(
                (o) =>
                    o.operation.equals('profile.set_timezone') &
                    o.state.isIn([...OutboxState.unacked]),
              )
              ..orderBy([(o) => OrderingTerm.desc(o.seq)])
              ..limit(1))
            .getSingleOrNull();
    final queuedZone = queued == null
        ? null
        : (jsonDecode(queued.payload) as Map)['timezone'] as String?;
    return TimezoneStatus(
      inForce: calendar.zoneNow(deviceNow),
      pending: calendar.pendingAfter(deviceNow),
      calendar: calendar,
      queuedZone: queuedZone,
      queuedNeedsAttention: queued?.state == OutboxState.needsAttention,
      followDevice: settings[followDevice] == '1',
      dismissed: {
        for (final key in settings.keys)
          if (key.startsWith(_notNowPrefix)) key.substring(_notNowPrefix.length),
      },
    );
  }
}

class TimezoneStatus {
  /// The habit-calendar zone in force now.
  final String inForce;

  /// A confirmed change that takes effect at the start of the next day, if any.
  final CalendarEntry? pending;
  final AccountCalendar calendar;

  /// A change written on this device and not yet acknowledged ("Waiting to sync").
  final String? queuedZone;
  final bool queuedNeedsAttention;
  final bool followDevice;
  final Set<String> dismissed;

  const TimezoneStatus({
    required this.inForce,
    required this.pending,
    required this.calendar,
    required this.queuedZone,
    required this.queuedNeedsAttention,
    required this.followDevice,
    required this.dismissed,
  });

  /// The zone the account is heading to: queued, else pending, else the one in force.
  String get target => queuedZone ?? pending?.timezone ?? inForce;

  /// Ask-on-change (screen 04): only while following the device, when the device zone differs
  /// from the one in force, no change to it is pending or queued, and "Not now" was not chosen
  /// for it.
  bool shouldAsk(String? deviceZone) =>
      followDevice &&
      deviceZone != null &&
      deviceZone.isNotEmpty &&
      deviceZone != inForce &&
      deviceZone != pending?.timezone &&
      deviceZone != queuedZone &&
      !dismissed.contains(deviceZone);
}
