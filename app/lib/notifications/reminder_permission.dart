import '../data/timezone_view.dart';
import 'notification_scheduler.dart';

/// Notification permission for reminders (Phase 3.2b, screens 04 and 11). The OS prompt is
/// shown only when the user taps Allow, and at most once on this device: after a refusal the
/// app shows the device's truth and offers Settings, never another prompt. "Set up reminders
/// later" is remembered and never prompts either.
class ReminderPermission {
  static const askedKey = 'notification_permission_asked';
  static const laterKey = 'reminders_later';

  ReminderPermission(this.settings, this.scheduler);

  final DeviceSettings settings;
  final NotificationScheduler scheduler;

  Future<NotificationPermission> state() async =>
      scheduler.permission(asked: await settings.read(askedKey) == '1');

  Future<bool> get later async => await settings.read(laterKey) == '1';

  /// The user tapped Allow. Prompts once; afterwards opens the device settings instead.
  Future<NotificationPermission> allow() async {
    final current = await state();
    if (current == NotificationPermission.authorized ||
        current == NotificationPermission.provisional) {
      return current;
    }
    if (await settings.read(askedKey) == '1') {
      await scheduler.openSettings();
      return state();
    }
    await settings.write(askedKey, '1');
    await scheduler.requestPermission();
    return state();
  }

  Future<void> setUpLater() => settings.write(laterKey, '1');

  Future<void> openSettings() => scheduler.openSettings();
}
