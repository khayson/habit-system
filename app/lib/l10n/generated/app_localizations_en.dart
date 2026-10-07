// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Habit System';

  @override
  String get statusTitle => 'Server connection';

  @override
  String get statusSubtitle => 'Checks that this device can reach the habit service.';

  @override
  String get statusChecking => 'Checking the connection…';

  @override
  String get statusOnline => 'Connected';

  @override
  String get statusOffline => 'Not connected';

  @override
  String get statusServerTime => 'Server time (UTC)';

  @override
  String get statusServerTimeLocal => 'On this device';

  @override
  String get statusRequestId => 'Request ID';

  @override
  String get statusCheckAgain => 'Check again';

  @override
  String get statusOfflineHint =>
      'Logging never waits for the network. Changes stay on this device until they sync.';

  @override
  String get protectedPlaceholder => 'Signed in. Your habits appear here in a later build.';
}
