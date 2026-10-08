import 'package:habit/notifications/notification_scheduler.dart';
import 'package:habit/notifications/reminder_planner.dart';

/// Stands in for the OS: what is scheduled, every call, and a settable permission.
class FakeNotificationScheduler implements NotificationScheduler {
  NotificationPermission osState = NotificationPermission.unknown;

  /// What the OS would answer to the prompt.
  bool grantOnRequest = false;
  int requests = 0;
  int settingsOpened = 0;
  final Map<int, (PlannedNotification, String)> pending = {};
  final List<String> calls = [];

  @override
  Future<NotificationPermission> permission({required bool asked}) async {
    if (osState == NotificationPermission.unknown && asked) return NotificationPermission.denied;
    return osState;
  }

  @override
  Future<bool> requestPermission() async {
    requests++;
    osState = grantOnRequest ? NotificationPermission.authorized : NotificationPermission.denied;
    return grantOnRequest;
  }

  @override
  Future<void> schedule(PlannedNotification n, {required String title, String? body}) async {
    calls.add('schedule ${n.id}');
    pending[n.id] = (n, title);
  }

  @override
  Future<void> cancel(int id) async {
    calls.add('cancel $id');
    pending.remove(id);
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}
