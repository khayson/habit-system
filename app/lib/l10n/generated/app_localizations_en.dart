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
  String get navToday => 'Today';

  @override
  String get navHabits => 'Habits';

  @override
  String get navInsights => 'Insights';

  @override
  String get navProfile => 'Profile';

  @override
  String navLater(String tab) {
    return '$tab, arrives in a later update';
  }

  @override
  String get libraryTitle => 'Your habits';

  @override
  String librarySubtitle(int active, int archived) {
    String _temp0 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$active active routines',
      one: '1 active routine',
    );
    return '$_temp0 · $archived archived';
  }

  @override
  String get librarySearch => 'Search your habits';

  @override
  String get libraryAll => 'All';

  @override
  String get libraryCreate => 'Create a habit';

  @override
  String get libraryNoMatch => 'No habits match your search.';

  @override
  String libraryOpen(String name, String detail) {
    return 'Open $name. $detail';
  }

  @override
  String get typeYesNo => 'Yes / no';

  @override
  String get typeQuantity => 'Quantity';

  @override
  String get typeDuration => 'Duration';

  @override
  String get typeUnknown => 'Needs an app update';

  @override
  String get freqDaily => 'daily';

  @override
  String get freqWeekdays => 'weekdays';

  @override
  String freqWeekly(int count) {
    return '$count× / week';
  }

  @override
  String freqInterval(int days) {
    return 'every $days days';
  }

  @override
  String get freqUnknown => 'custom schedule';

  @override
  String minutesShort(String minutes) {
    return '$minutes min';
  }

  @override
  String rowDetail(String type, String target, String frequency) {
    return '$type · $target · $frequency';
  }

  @override
  String rowDetailNoTarget(String type, String frequency) {
    return '$type · $frequency';
  }

  @override
  String todayCompletedAt(String time) {
    return 'Completed at $time';
  }

  @override
  String todayCompletedAtWaiting(String time) {
    return 'Completed at $time · waiting to sync';
  }

  @override
  String todayWeek(int done, int target) {
    return '$done of $target this week · counted on this device';
  }

  @override
  String todayOpenDetail(String name) {
    return 'Open $name';
  }

  @override
  String askZoneTitle(String zone) {
    return 'Your device is now in $zone. Use it for your days?';
  }

  @override
  String get askZoneBody => 'The change applies from the start of your next day.';

  @override
  String get askZoneUse => 'Use';

  @override
  String get askZoneNotNow => 'Not now';

  @override
  String detailSubtitle(String schedule, String category) {
    return '$schedule · $category';
  }

  @override
  String get categoryMindfulness => 'Mindfulness';

  @override
  String statDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String statWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String statPeriods(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: '1 time',
    );
    return '$_temp0';
  }

  @override
  String get statNotYet => 'Not yet';

  @override
  String get statCurrent => 'Current streak';

  @override
  String statCurrentAsOf(String date) {
    return 'Current streak · as of $date';
  }

  @override
  String get statBest => 'Best streak';

  @override
  String get statToday => 'Today';

  @override
  String get statTodayDone => 'Today · done';

  @override
  String get statDone => 'Done';

  @override
  String get heatmapMonth => 'Month';

  @override
  String get heatmapPrevious => 'Previous month';

  @override
  String get heatmapNext => 'Next month';

  @override
  String get legendComplete => 'Complete';

  @override
  String get legendProtected => 'Protected';

  @override
  String get legendMissed => 'Missed (–)';

  @override
  String get legendNotDue => 'Not due (outline)';

  @override
  String get statusComplete => 'Complete';

  @override
  String get statusProtected => 'Protected';

  @override
  String get statusMissed => 'Missed';

  @override
  String get statusNotDue => 'Not due';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusUpcoming => 'Upcoming';

  @override
  String cellLabel(String date, String status) {
    return '$date, $status';
  }

  @override
  String cellLabelProvisional(String date, String status) {
    return '$date, $status, saved on this device';
  }

  @override
  String streakProtected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count protected days',
      one: '1 protected day',
    );
    return 'Your streak includes $_temp0.';
  }

  @override
  String get streakPause => 'A missed day is a pause, not a failure.';

  @override
  String get olderNeedsConnection => 'Older history needs a connection';

  @override
  String get olderLoading => 'Loading older history…';

  @override
  String get heatmapProvisional =>
      'Some days are counted on this device and are confirmed after syncing.';

  @override
  String get historyTitle => 'Your history';

  @override
  String get historySubtitle => 'Check-ins stay editable and traceable.';

  @override
  String get historyTabToday => 'Today';

  @override
  String get historyTabHistory => 'History';

  @override
  String historyRow(String date, String name) {
    return '$date · $name';
  }

  @override
  String historyRowDetail(String value, String time) {
    return '$value · completed at $time';
  }

  @override
  String historyRowWaiting(String value) {
    return '$value · waiting to sync';
  }

  @override
  String get historyEdit => 'Edit';

  @override
  String historyEditLabel(String date) {
    return 'Edit the check-in for $date';
  }

  @override
  String get historyEmpty => 'No check-ins in the last 30 days.';

  @override
  String get historyEmptyToday => 'No check-in yet today.';

  @override
  String get historyAddTitle => 'Add a past check-in';

  @override
  String get historyDateLabel => 'Local habit date';

  @override
  String get historyDateChoose => 'Choose calendar day';

  @override
  String get historyValueCheckIn => 'Check-in';

  @override
  String get historyValueDone => 'Done';

  @override
  String get historyValueNotDone => 'Not done';

  @override
  String get historyValueDuration => 'Duration';

  @override
  String get historyValueAmount => 'Amount';

  @override
  String get historyMinutesUnit => 'minutes';

  @override
  String historyTarget(String target) {
    return 'Target that day: $target';
  }

  @override
  String get historyNote =>
      'Uses your habit timezone for that date. Streak and freeze changes are reconciled after syncing.';

  @override
  String get historySave => 'Save past check-in';

  @override
  String get historySaved => 'Saved on this device. It syncs when you are online.';

  @override
  String get historyRefuseFuture => 'That date has not started yet in your habit calendar.';

  @override
  String get historyRefuseOld => 'Past check-ins can go back 30 days.';

  @override
  String get historyRefuseInactive => 'This habit was not active on that date.';

  @override
  String get historyValueInvalidMinutes => 'Enter a whole number of minutes, like 10.';

  @override
  String get historyValueInvalidAmount => 'Enter an amount, like 1.5.';

  @override
  String get setupSubtitle => 'Get reminders that respect your routine.';

  @override
  String get setupEdit => 'Edit';

  @override
  String get setupEditZone => 'Edit habit timezone';

  @override
  String get setupFollow => 'Follow device timezone';

  @override
  String get setupFollowNote => 'Ask before changing your habit calendar';

  @override
  String setupQueued(String zone) {
    return '$zone · waiting to sync';
  }

  @override
  String setupPending(String zone, String time) {
    return '$zone · changes at the start of your next day ($time)';
  }

  @override
  String get setupQueuedProblem => 'This change needs a look. Open Sync to review it.';

  @override
  String get setupNextDay => 'A new timezone applies from the start of your next day.';

  @override
  String get zonePickerTitle => 'Choose a timezone';

  @override
  String get zoneSearch => 'Search timezones';

  @override
  String get zoneNoMatch => 'No timezones match.';

  @override
  String zoneRow(String city, String offset) {
    return '$city, $offset';
  }

  @override
  String get newHabitCreate => 'Create habit';

  @override
  String get reminderBody => 'A gentle reminder for today.';

  @override
  String get remindersTitle => 'Local reminders';

  @override
  String get remindersNotAllowed => 'Not allowed yet';

  @override
  String get remindersAllowed => 'Allowed';

  @override
  String get remindersOff => 'Off in device settings';

  @override
  String get remindersAllow => 'Allow';

  @override
  String get remindersOpenSettings => 'Open settings';

  @override
  String get remindersOfflineTitle => 'Reminders work offline';

  @override
  String get remindersOfflineBody =>
      'Delivery also depends on device permissions and battery settings. You can skip this for now.';

  @override
  String get remindersLater => 'Set up reminders later';

  @override
  String get reminderEditorTitle => 'Gentle reminders';

  @override
  String reminderEditorSubtitle(String habit) {
    return '$habit · notifications stay on your device.';
  }

  @override
  String get reminderNewHabit => 'Your new habit';

  @override
  String get reminderDeniedTitle => 'Notifications are off';

  @override
  String get reminderDeniedBody =>
      'Enable notifications in device settings before these reminders can appear.';

  @override
  String get reminderOpenDeviceSettings => 'Open device settings';

  @override
  String get reminderAskTitle => 'Notifications are not allowed yet';

  @override
  String get reminderAskBody =>
      'These reminders appear once notifications are allowed on this device.';

  @override
  String reminderNext(String when) {
    return 'Next reminder: $when';
  }

  @override
  String get reminderEveryDay => 'Repeat every day';

  @override
  String get reminderWeekdays => 'Repeat on weekdays';

  @override
  String reminderOnDays(String days) {
    return 'Repeat on $days';
  }

  @override
  String reminderChooseTime(String time) {
    return 'Choose the reminder time, now $time';
  }

  @override
  String reminderDayLabel(String day, String state) {
    return '$day, $state';
  }

  @override
  String get reminderDayOn => 'on';

  @override
  String get reminderDayOff => 'off';

  @override
  String get reminderEnabled => 'Reminder enabled';

  @override
  String get reminderReadyWhenAllowed => 'Ready when permission is allowed';

  @override
  String get reminderOnThisDevice => 'Arrives on this device';

  @override
  String get reminderOther => 'Other reminders';

  @override
  String get reminderNote =>
      'Local reminders do not depend on a network connection. Battery settings may delay delivery.';

  @override
  String get reminderSave => 'Save reminder';

  @override
  String get reminderNeedsDay => 'Choose at least one day.';

  @override
  String get reminderRow => 'Reminder';

  @override
  String get reminderRemove => 'Remove reminder';

  @override
  String reminderEditAt(String time) {
    return 'Edit the reminder at $time';
  }

  @override
  String get reminderSummaryNone => 'None';

  @override
  String get reminderSummaryOff => 'Off';

  @override
  String get reminderSummaryEveryDay => 'every day';

  @override
  String get reminderSummaryWeekdays => 'weekdays';

  @override
  String reminderSummary(String time, String days) {
    return '$time · $days';
  }

  @override
  String get reminderRowNone => 'Not set';

  @override
  String reminderRowSet(String time) {
    return '$time · local device time';
  }
}
