/// Phase 4.2a (B4): how many reminders one account hands to the OS at a time. The planner keeps
/// the nearest ones; the rest are planned again at the next replan (start, resume, any change).
/// A background top-up is Phase 8.
abstract final class NotificationCaps {
  /// iOS keeps at most 64 pending local notifications per app; 4 stay free for other uses.
  static const ios = 60;

  /// Android limits an app to 500 alarms; 50 stay free for the system and other features.
  static const android = 450;
}
