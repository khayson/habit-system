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
  String get back => 'Back';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldName => 'Your name';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get errorEmailInvalid => 'Enter an email address, like name@example.com.';

  @override
  String get errorPasswordShort => 'Use at least 12 characters.';

  @override
  String get errorNameRequired => 'Enter your name.';

  @override
  String get errorNameTooLong => 'Use 80 characters or fewer.';

  @override
  String get errorRequired => 'This field is needed.';

  @override
  String get errorNetwork => 'Could not reach the server. Check your connection and try again.';

  @override
  String get errorRateLimited => 'Too many attempts for now. Try again in a minute.';

  @override
  String get errorGeneric => 'Something went wrong. Try again.';

  @override
  String get signInTitle => 'Welcome back';

  @override
  String get signInSubtitle => 'Your routines are right where you left them.';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signInPrivateTitle => 'Private by default';

  @override
  String get signInPrivateBody =>
      'Your habits and history belong to you. Export them whenever you need.';

  @override
  String get signInCreateAccount => 'New here? Create an account';

  @override
  String get createAccountTitle => 'Make room for you';

  @override
  String get createAccountSubtitle => 'A few details, then your first habit.';

  @override
  String get createAccountPasswordHelper => 'Use at least 12 characters.';

  @override
  String get createAccountTerms => 'I agree to the Terms and Privacy Policy.';

  @override
  String get createAccountTermsNeeded => 'Agree to the Terms and Privacy Policy to continue.';

  @override
  String get createAccountNoPressureTitle => 'No pressure. No public profile.';

  @override
  String get createAccountNoPressureBody => 'Start small. You can change your routines any time.';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get createAccountSignIn => 'Already have an account? Sign in';

  @override
  String get setupTitle => 'Your day, your time';

  @override
  String get setupZoneNote =>
      'Habit days use your saved timezone. Past check-ins keep their original dates.';

  @override
  String get setupContinue => 'Continue';

  @override
  String setupZoneLabel(String zone) {
    return 'Habit timezone $zone';
  }

  @override
  String todayGreetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String todayGreetingAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String todayGreetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get todayGreetingPlain => 'Today';

  @override
  String todaySummary(int done, int total) {
    return '$done of $total habits complete';
  }

  @override
  String get todaySummaryProvisional => 'Includes changes waiting to sync.';

  @override
  String get todayOpening => 'Opening your habits…';

  @override
  String get todayLoadError => 'Your habits could not be shown. Try again.';

  @override
  String get todayRetry => 'Try again';

  @override
  String get todayDone => 'Done';

  @override
  String get todayDoneWaiting => 'Done · waiting to sync';

  @override
  String get todayNotDone => 'Tap to check in';

  @override
  String get todayNotDoneWaiting => 'Not checked in · waiting to sync';

  @override
  String get todayNeedsLook => 'Needs a look · tap to review';

  @override
  String get todayUnknownType => 'Update the app to log this habit.';

  @override
  String get todayOtherType => 'Logging this kind of habit arrives in a later update.';

  @override
  String get todayNewHabitWaiting => 'New · waiting to sync';

  @override
  String todayCheckIn(String name) {
    return 'Check in $name';
  }

  @override
  String todayUndo(String name) {
    return 'Undo check-in for $name';
  }

  @override
  String get todayCreateHabit => 'Create a habit';

  @override
  String get emptyTitle => 'Your first step';

  @override
  String get emptySubtitle => 'One small routine is a great place to start.';

  @override
  String get emptyHeading => 'No habits yet';

  @override
  String get emptyBody =>
      'Try a glass of water, five minutes of reading, or a moment to breathe. Start with one.';

  @override
  String get emptyButton => 'Create your first habit';

  @override
  String get chipSynced => 'Synced';

  @override
  String get chipSyncing => 'Syncing…';

  @override
  String get chipOffline => 'Offline';

  @override
  String chipWaiting(int count) {
    return '$count waiting';
  }

  @override
  String get chipNeedsLook => 'Needs a look';

  @override
  String get chipPaused => 'Sync paused';

  @override
  String get chipNotYet => 'Not synced yet';

  @override
  String chipOpenQueue(String status) {
    return 'Sync status: $status. Open sync details.';
  }

  @override
  String get resolveTitle => 'This check-in needs a look';

  @override
  String get resolveDiscard => 'Discard my change';

  @override
  String get resolveOpenQueue => 'Open sync details';

  @override
  String get discardTitle => 'Discard this change?';

  @override
  String get discardBody => 'It stays recorded on this device but will not be sent.';

  @override
  String get discardConfirm => 'Discard';

  @override
  String get cancel => 'Cancel';

  @override
  String get reasonVersionConflict => 'It changed on another device first.';

  @override
  String get reasonResourceDeleted => 'It was removed on another device first.';

  @override
  String get reasonParentRejected => 'Its habit was not saved.';

  @override
  String get reasonFutureEvent => 'This device\'s clock was ahead when it was saved.';

  @override
  String get reasonGeneric => 'The server could not accept it.';

  @override
  String get queueTitle => 'Saved on this device';

  @override
  String get queueSubtitle => 'You can keep logging without a connection.';

  @override
  String get queuePending => 'Pending check-ins';

  @override
  String get queueLastSynced => 'Last synced';

  @override
  String get queueNever => 'Not yet';

  @override
  String get queueOfflineTitle => 'Waiting for a connection';

  @override
  String get queueOfflineBody => 'Your outbox stays safe until each change is acknowledged.';

  @override
  String get queuePausedTitle => 'Sync is paused';

  @override
  String queuePausedBody(String code) {
    return 'The server is not accepting sync requests from this app ($code). Your changes stay on this device. Updating the app may help.';
  }

  @override
  String get queueSyncedTitle => 'Everything is synced';

  @override
  String get queueSyncedBody => 'Changes you make now are saved here first, then sent.';

  @override
  String get queueSyncNow => 'Sync now';

  @override
  String get queueTryAgain => 'Try again';

  @override
  String get queueFooter => 'Duplicate retries never duplicate a check-in.';

  @override
  String get queueStateQueued => 'Queued';

  @override
  String get queueStateSending => 'Sending';

  @override
  String get queueStateRetrying => 'Retrying later';

  @override
  String get queueStateWaiting => 'Waiting for its habit';

  @override
  String get queueStateNeedsLook => 'Needs a look';

  @override
  String get queueChangeNewHabit => 'New habit';

  @override
  String get queueChangeCheckIn => 'Checked in';

  @override
  String get queueChangeUndo => 'Check-in undone';

  @override
  String get queueChangeRemoved => 'Removed';

  @override
  String get queueChangeOther => 'Change';

  @override
  String queueItemTitle(String habit, String change) {
    return '$habit · $change';
  }

  @override
  String queueItemWhen(String when) {
    return '$when · waiting to sync';
  }

  @override
  String get queueUnnamedHabit => 'A habit';

  @override
  String get newHabitTitle => 'A new routine';

  @override
  String get newHabitSubtitle => 'Choose something small and specific.';

  @override
  String get newHabitName => 'Habit name';

  @override
  String get newHabitNameTooLong => 'Use 100 characters or fewer.';

  @override
  String get newHabitType => 'Habit type';

  @override
  String get newHabitTypeYesNo => 'Yes / no';

  @override
  String get newHabitCategory => 'Category';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryMindful => 'Mindful';

  @override
  String get categoryLearning => 'Learning';

  @override
  String get newHabitSchedule => 'Schedule';

  @override
  String get newHabitDaily => 'Every day';

  @override
  String get newHabitCreate => 'Create habit';
}
