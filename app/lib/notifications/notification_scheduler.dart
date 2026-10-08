import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_planner.dart';

/// What the OS says about notifications for this app (Phase 3.2b). `provisional` is iOS's quiet
/// delivery; Android never reports it.
enum NotificationPermission { unknown, authorized, provisional, denied }

/// The device's notification scheduler. The app schedules through this seam only, so tests use
/// a fake and nothing else imports the plugin.
abstract interface class NotificationScheduler {
  /// The OS state. [asked] is whether this device already showed the OS prompt.
  Future<NotificationPermission> permission({required bool asked});

  /// Shows the OS prompt (Android 13+). Only ever called after the user taps Allow.
  Future<bool> requestPermission();

  Future<void> schedule(PlannedNotification notification, {required String title, String? body});

  Future<void> cancel(int id);

  /// The device's notification settings for this app.
  Future<void> openSettings();
}

/// flutter_local_notifications, Android first. Inexact alarms only (no SCHEDULE_EXACT_ALARM);
/// the plugin's boot receiver keeps them across a reboot, and the app replans on start.
class LocalNotificationsScheduler implements NotificationScheduler {
  LocalNotificationsScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Your habit reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> _init() => _ready ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      )
      .then((_) {});

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<NotificationPermission> permission({required bool asked}) async {
    await _init();
    if (defaultTargetPlatform != TargetPlatform.android) return NotificationPermission.unknown;
    final enabled = await _android?.areNotificationsEnabled() ?? false;
    if (enabled) return NotificationPermission.authorized;
    return asked ? NotificationPermission.denied : NotificationPermission.unknown;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required String title,
    String? body,
  }) async {
    await _init();
    await _plugin.zonedSchedule(
      id: notification.id,
      scheduledDate: tz.TZDateTime.from(notification.fireAt, tz.UTC),
      notificationDetails: const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: 'slot:${notification.slotDate}:${notification.reminderId}',
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> openSettings() async {
    await _init();
    await _plugin.openAppNotificationSettings();
  }
}
