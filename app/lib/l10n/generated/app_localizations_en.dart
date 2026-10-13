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
  String get legalTerms => 'Terms';

  @override
  String get legalPrivacy => 'Privacy Policy';

  @override
  String get legalOpensInBrowser => 'Opens in your browser';

  @override
  String get legalOpenFailedTitle => 'The page didn\'t open here';

  @override
  String get legalOpenFailedBody => 'You can copy the link and open it in any browser.';

  @override
  String get legalCopyLink => 'Copy link';

  @override
  String get legalLinkCopied => 'Link copied';

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
  String get todaySummaryProvisional =>
      'Includes changes waiting to sync. Rewards update after syncing.';

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
  String get queueOfflineBody =>
      'Your outbox stays safe until each change is acknowledged. Rewards update after syncing.';

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
  String get queueYourProfile => 'Your profile';

  @override
  String get queueChangeProfile => 'Name and location';

  @override
  String get queueChangeTimezone => 'Time zone';

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
  String get categoryProductivity => 'Productivity';

  @override
  String get categoryOther => 'Other';

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
  String get reminderTitleHidden => 'A habit reminder';

  @override
  String get profileTitle => 'Your space';

  @override
  String get profileSubtitle => 'Preferences that follow your life.';

  @override
  String get profileLocationEmpty => 'Add your city and country';

  @override
  String get profileEdit => 'Edit profile';

  @override
  String avatarLabel(String name) {
    return 'Profile photo of $name';
  }

  @override
  String get avatarChangeHint => 'Change the profile photo';

  @override
  String get photoSheetTitle => 'Profile photo';

  @override
  String get photoChoose => 'Choose photo';

  @override
  String get photoTake => 'Take photo';

  @override
  String get photoRemove => 'Remove photo';

  @override
  String get photoCropTitle => 'Crop photo';

  @override
  String get photoRejected => 'That photo couldn\'t be used. Choose another.';

  @override
  String get photoWaiting => 'Waiting to upload';

  @override
  String get profileEditQueued => 'Waiting to sync';

  @override
  String get profileTimezone => 'Timezone';

  @override
  String get profileTimezoneEditLabel => 'Edit the timezone';

  @override
  String get profileReminders => 'Reminders';

  @override
  String profileRemindersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders',
      one: '1 reminder',
      zero: 'No reminders',
    );
    return '$_temp0';
  }

  @override
  String get profileNotificationsOn => 'notifications on';

  @override
  String get profileNotificationsOff => 'off in device settings';

  @override
  String get profileNotificationsUnknown => 'notifications not allowed yet';

  @override
  String profileRemindersLine(String count, String permission) {
    return '$count · $permission';
  }

  @override
  String get remindersSheetTitle => 'Reminders';

  @override
  String get remindersSheetEmpty => 'No reminders yet. Add one from a habit.';

  @override
  String remindersSheetHabitLabel(String habit) {
    return 'Reminders for $habit';
  }

  @override
  String get hideNamesTitle => 'Hide habit names in notifications';

  @override
  String get hideNamesBody => 'Reminders on the lock screen won\'t say which habit they are for.';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String signOutUnsynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes haven\'t synced yet. They stay saved on this phone and upload the next time you sign in here.',
      one: '1 change hasn\'t synced yet. It stays saved on this phone and uploads the next time you sign in here.',
    );
    return '$_temp0';
  }

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get fieldCity => 'City';

  @override
  String get fieldCountry => 'Country';

  @override
  String get countryNone => 'No country';

  @override
  String get countrySearch => 'Search countries';

  @override
  String get countryPickerTitle => 'Country';

  @override
  String get profileSave => 'Save';

  @override
  String get errorCityTooLong => 'Use 60 characters or fewer.';

  @override
  String get photoPickFailed =>
      'We couldn\'t open your photos. You can allow access in your device settings.';

  @override
  String get photoAddFailed => 'That photo couldn\'t be added. Try another.';

  @override
  String get saveFailed => 'We couldn\'t save that. Try again.';

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

  @override
  String get targetAmount => 'Amount';

  @override
  String get targetUnit => 'Unit';

  @override
  String get targetUnitHint => 'ml, pages';

  @override
  String get targetMinutes => 'Minutes';

  @override
  String get targetMinutesSuffix => 'minutes';

  @override
  String get unknownTypeTitle => 'This habit needs a newer version of the app';

  @override
  String get unknownTypeBody => 'Its history is safe. Update the app to change it.';

  @override
  String get targetErrorRequired => 'Add a daily target.';

  @override
  String get targetErrorNotNumber => 'Use a number, such as 250 or 1.5.';

  @override
  String get targetErrorTooPrecise => 'Use up to 3 decimal places.';

  @override
  String get targetErrorNotPositive => 'Use a number above zero.';

  @override
  String get targetErrorTooLarge => 'Use a smaller number.';

  @override
  String get targetErrorUnitRequired => 'Add a unit, such as ml or pages.';

  @override
  String get targetErrorUnitTooLong => 'Use 24 characters or fewer.';

  @override
  String get problemCategory => 'Choose a category.';

  @override
  String get problemUnitNotAllowed => 'This habit type doesn\'t use a unit.';

  @override
  String get problemFrequencyType => 'Choose a schedule.';

  @override
  String get problemWeekdays => 'Choose at least one day.';

  @override
  String get problemWeeklyCount => 'Choose between 1 and 7 times.';

  @override
  String get problemInterval => 'Choose every 1 to 365 days.';

  @override
  String get problemIntervalAnchor => 'Choose a start date.';

  @override
  String get freqTitle => 'A flexible schedule';

  @override
  String freqSubtitle(String habit) {
    return 'Choose how often $habit fits your week.';
  }

  @override
  String get freqSubtitleNoName => 'Choose how often this habit fits your week.';

  @override
  String get freqDailyTitle => 'Every day';

  @override
  String get freqDailyBody => 'A daily routine';

  @override
  String get freqWeekdaysTitle => 'Specific weekdays';

  @override
  String get freqWeekdaysBody => 'Pick the days that work for you';

  @override
  String get freqWeeklyTitle => 'Times per week';

  @override
  String freqWeeklyBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Any $count distinct days in a local week',
      one: 'Any 1 day in a local week',
    );
    return '$_temp0';
  }

  @override
  String get freqIntervalTitle => 'Custom interval';

  @override
  String get freqIntervalBody => 'Every N days from a start date';

  @override
  String get freqUse => 'Use this schedule';

  @override
  String get freqSelected => 'Selected';

  @override
  String get freqNotSelected => 'Not selected';

  @override
  String get freqDailyDetail => 'Each local day counts once';

  @override
  String freqWeekdaysDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days each week',
      one: '1 day each week',
      zero: 'No days chosen yet',
    );
    return '$_temp0';
  }

  @override
  String freqWeeklySummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times each week',
      one: 'Once each week',
    );
    return '$_temp0';
  }

  @override
  String get freqWeeklyDetail => 'Monday–Sunday · each day counts once';

  @override
  String freqIntervalSummary(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Every $days days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String freqIntervalDetail(String date) {
    return 'Starting $date';
  }

  @override
  String freqIntervalFrom(String schedule, String date) {
    return '$schedule from $date';
  }

  @override
  String get freqWeekInfoTitle => 'The week is still yours';

  @override
  String get freqWeekInfoBody => 'An unfinished week is pending, not missed.';

  @override
  String get freqDaysLabel => 'Days';

  @override
  String get freqTimesLabel => 'Times per week';

  @override
  String get freqEveryLabel => 'Repeat every';

  @override
  String freqEveryValue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get freqStartDate => 'Start date';

  @override
  String get freqChooseStart => 'Choose the start date';

  @override
  String get freqFewer => 'Fewer';

  @override
  String get freqMore => 'More';

  @override
  String listAnd(String head, String last) {
    return '$head and $last';
  }

  @override
  String get newHabitTarget => 'Daily target';

  @override
  String editTitle(String name) {
    return 'Edit $name';
  }

  @override
  String get editSubtitle => 'Adjust your routine without losing history.';

  @override
  String get editTargetUnit => 'Target and unit';

  @override
  String editTypeLine(String type) {
    return 'Type: $type';
  }

  @override
  String get editTypeNote =>
      'A habit\'s type can\'t be changed. Start a new habit to try a different one.';

  @override
  String get editCategory => 'Category';

  @override
  String get editReminders => 'Reminders';

  @override
  String editRemindersSummary(int count, String times) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders · $times',
      one: '$times',
      zero: 'Not set',
    );
    return '$_temp0';
  }

  @override
  String get editHistoryTitle => 'History stays unchanged';

  @override
  String get editHistoryBody =>
      'New targets apply from the next eligible period. Past check-ins keep their original target.';

  @override
  String get editSave => 'Save changes';

  @override
  String get editWaiting => 'Waiting to sync';

  @override
  String editStarts(String date) {
    return 'New target starts $date';
  }

  @override
  String get editArchive => 'Archive this habit';

  @override
  String get archiveTitle => 'Archive this habit?';

  @override
  String get archiveBody =>
      'Your history stays. It leaves Today and sends no reminders. You can restore it from Archived routines.';

  @override
  String get archiveConfirm => 'Archive';

  @override
  String get archiveNotNow => 'Not now';

  @override
  String get editBlockedAttention => 'A change to this habit needs a look before you can edit it.';

  @override
  String get editBlockedArchived =>
      'This habit is archived. Restore it from Archived routines to make changes.';

  @override
  String get editReview => 'Review the change';

  @override
  String get editGone => 'This habit is no longer on this device.';

  @override
  String get chooseCategory => 'Choose a category';

  @override
  String get archivedTitle => 'Archived routines';

  @override
  String libraryActive(int active) {
    String _temp0 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$active active routines',
      one: '1 active routine',
    );
    return '$_temp0';
  }

  @override
  String libraryArchivedLink(int archived) {
    return '$archived archived';
  }

  @override
  String get libraryArchivedLinkHint => 'Opens Archived routines';

  @override
  String get archivedSubtitle => 'Taking a pause keeps your past progress.';

  @override
  String archivedRow(String date, String category) {
    return 'Archived $date · $category';
  }

  @override
  String archivedRowNoDate(String category) {
    return 'Archived · $category';
  }

  @override
  String get archivedRestore => 'Restore';

  @override
  String archivedRestoreLabel(String name) {
    return 'Restore $name';
  }

  @override
  String get restoreInfoTitle => 'Restore from today';

  @override
  String get restoreInfoBody =>
      'A new active schedule begins today. Archived dates never become missed days.';

  @override
  String get startAgainTitle => 'Start again, gently';

  @override
  String get startAgainBody => 'You can begin with a tiny routine. No streak needs to be perfect.';

  @override
  String get startAgainLink => 'Create a new habit';

  @override
  String get restoredMessage => 'Restored. A new schedule begins today.';

  @override
  String dayMonth(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('d MMM', localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String detailEditLabel(String name) {
    return 'Edit $name';
  }

  @override
  String fullDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('d MMM y', localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String weekdayDate(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('EEEE, d MMMM y', localeName);
    final String dateString = dateDateFormat.format(date);

    return '$dateString';
  }

  @override
  String dayMonthTime(DateTime date, DateTime time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('d MMM', localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$dateString, $timeString';
  }

  @override
  String progressOf(String value, String target, String unit) {
    return '$value / $target $unit';
  }

  @override
  String plusAmount(String amount) {
    return '+$amount';
  }

  @override
  String minutesSeconds(int minutes, int seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String get minutesUnit => 'min';

  @override
  String get amountTitleProgress => 'Add progress';

  @override
  String get amountTitleTime => 'Add time';

  @override
  String amountSubtitle(String habit, String progress) {
    return '$habit · $progress saved today';
  }

  @override
  String amountCustomIn(String unit) {
    return 'Custom amount in $unit';
  }

  @override
  String get amountCustomMinutes => 'Custom time in minutes';

  @override
  String get amountStepperLabel => 'Amount to add';

  @override
  String get amountLess => 'Less';

  @override
  String get amountMore => 'More';

  @override
  String get amountAfterSaving => 'After saving';

  @override
  String get amountNotComplete => 'Not complete yet';

  @override
  String get amountReached => 'Today\'s target is reached';

  @override
  String amountAdd(String amount) {
    return 'Add $amount';
  }

  @override
  String get amountCancel => 'Cancel · keep saved value';

  @override
  String get amountTimeIt => 'Time it instead';

  @override
  String get amountRequired => 'Add an amount.';

  @override
  String get amountTooMuch => 'Today can\'t hold that much.';

  @override
  String get amountOneTap => 'This habit is checked in with one tap on Today.';

  @override
  String get amountBack => 'Back';

  @override
  String progressOfSpoken(String value, String target, String unit) {
    return '$value of $target $unit';
  }

  @override
  String todayProgressDone(String progress) {
    return '$progress · done';
  }

  @override
  String todayTimerRunning(String time) {
    return 'Timer running · $time';
  }

  @override
  String todayTimerPaused(String time) {
    return 'Timer paused · $time';
  }

  @override
  String todayTimerRunningSpoken(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'Timer running, $_temp0 so far';
  }

  @override
  String todayTimerPausedSpoken(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'Timer paused at $_temp0';
  }

  @override
  String get todayOpenTimer => 'Open timer';

  @override
  String todayAmountSpoken(String habit, String progress) {
    return '$habit: $progress';
  }

  @override
  String todayAddSpoken(String amount) {
    return 'Add $amount';
  }

  @override
  String get detailStartTimer => 'Start timer';

  @override
  String get timerRunningTitle => 'A moment to breathe';

  @override
  String timerRunningSubtitle(String habit, String minutes) {
    return '$habit · $minutes-minute daily target';
  }

  @override
  String get timerPausedTitle => 'Pause at your pace';

  @override
  String timerPausedSubtitle(String habit) {
    return '$habit · your elapsed time is preserved';
  }

  @override
  String timerOver(String elapsed, String target) {
    return '$elapsed / $target';
  }

  @override
  String timerSpoken(int elapsed, String target) {
    String _temp0 = intl.Intl.pluralLogic(
      elapsed,
      locale: localeName,
      other: '$elapsed minutes',
      one: '1 minute',
    );
    return '$_temp0 of $target minutes';
  }

  @override
  String get timerPause => 'Pause';

  @override
  String get timerResume => 'Resume';

  @override
  String timerTodayTotal(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes today',
      one: '1 minute today',
    );
    return '$_temp0';
  }

  @override
  String get timerKeepGoing =>
      'Keep going if you like. You can save partial time without pretending the habit is complete.';

  @override
  String get timerPauseButton => 'Pause timer';

  @override
  String get timerResumeButton => 'Resume timer';

  @override
  String get timerFinish => 'Save progress and finish';

  @override
  String get timerRunningNote => 'The timer continues locally without network access.';

  @override
  String get timerPausedNote => 'Returning to Today keeps partial progress.';

  @override
  String get timerPausedCardTitle => 'Timer paused';

  @override
  String timerPausedCardBody(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes are saved in the draft.',
      one: '1 minute is saved in the draft.',
    );
    return '$_temp0 Nothing is logged until you finish and save.';
  }

  @override
  String timerSavedMinutes(int minutes) {
    return 'Saved $minutes min.';
  }

  @override
  String timerSavedSeconds(int seconds) {
    return 'Saved $seconds s.';
  }

  @override
  String get timerNothingToSave => 'Nothing to save yet.';

  @override
  String get timerGone => 'This timer is no longer here.';

  @override
  String get timerTooLong => 'This timer ran longer than a day can hold.';

  @override
  String get timerTooLongHint => 'You can add time yourself from Today.';

  @override
  String get timerTooMuchToday => 'Today can\'t hold that much time.';

  @override
  String get timerArchived => 'This habit is archived. Restore it to save this time.';

  @override
  String get timerDiscard => 'Discard timer';

  @override
  String get timerDiscardTitle => 'Discard this timer?';

  @override
  String get timerDiscardBody => 'The time so far won\'t be saved.';

  @override
  String get timerDiscardConfirm => 'Discard';

  @override
  String get timerKeep => 'Keep timer';

  @override
  String weekdayDayMonthTime(DateTime date, DateTime time) {
    final intl.DateFormat dateDateFormat = intl.DateFormat('EEE d MMM', localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    return '$dateString, $timeString';
  }

  @override
  String get entryDone => 'Done';

  @override
  String get entryNotDone => 'Not done';

  @override
  String get reviewTitle => 'Review one change';

  @override
  String reviewStaleSubtitle(String habit, String date) {
    return 'Both devices edited the same $habit entry on $date.';
  }

  @override
  String get reviewSafeTitle => 'Your check-in is safe';

  @override
  String get reviewSafeStaleBody =>
      'This absolute edit needs your choice. Quantity increments normally merge automatically.';

  @override
  String get reviewOnDevice => 'On this device';

  @override
  String get reviewLatestEntry => 'Latest synced entry';

  @override
  String get reviewLatestVersion => 'Latest synced version';

  @override
  String reviewEditedAt(String time, int version) {
    return 'Edited at $time · based on version $version';
  }

  @override
  String reviewRemovedAt(String time, int version) {
    return 'Removed at $time · based on version $version';
  }

  @override
  String reviewEditedElsewhere(int version) {
    return 'Edited on another device · version $version';
  }

  @override
  String reviewDeletedElsewhere(int version) {
    return 'Deleted on another device · version $version';
  }

  @override
  String get reviewArchivedElsewhere => 'Archived on another device';

  @override
  String get reviewChangedElsewhere => 'Changed on another device';

  @override
  String get reviewNote =>
      'Your choice becomes a reviewed edit against the latest version. If it changes again, you will review it again.';

  @override
  String get reviewNoteFields => 'Fields that differ take the values you choose.';

  @override
  String reviewKeepSynced(String value) {
    return 'Keep synced value · $value';
  }

  @override
  String reviewUseMine(String value) {
    return 'Use my value · $value';
  }

  @override
  String get reviewEntryRemoved => 'Entry removed';

  @override
  String get reviewRemoveEntry => 'Remove the entry';

  @override
  String reviewDeletedSubtitle(String habit) {
    return 'This $habit entry was deleted on another device.';
  }

  @override
  String get reviewDeletedBody =>
      'The entry for this day was deleted on another device. Your change stays here until you choose.';

  @override
  String get reviewDeleted => 'Deleted';

  @override
  String get reviewKeepDeleted => 'Keep it deleted';

  @override
  String reviewBringBack(String value) {
    return 'Bring it back · $value';
  }

  @override
  String get reviewBothRemoved => 'Both devices removed this entry.';

  @override
  String get reviewDone => 'Done';

  @override
  String reviewArchivedSubtitle(String habit) {
    return '$habit was archived on another device.';
  }

  @override
  String reviewArchivedBody(String habit) {
    return 'Restore $habit to save this check-in, or discard it.';
  }

  @override
  String get reviewArchived => 'Archived';

  @override
  String get reviewActive => 'Active';

  @override
  String reviewRestore(String habit) {
    return 'Restore $habit';
  }

  @override
  String reviewSaveCheckIn(String value) {
    return 'Save my check-in · $value';
  }

  @override
  String get reviewDiscardCheckIn => 'Discard this check-in';

  @override
  String reviewHabitSubtitle(String habit) {
    return 'Both devices edited $habit.';
  }

  @override
  String get reviewEditSafeTitle => 'Your edit is safe';

  @override
  String get reviewEditSafeBody => 'Your edit needs your choice before it is saved.';

  @override
  String get reviewKeepSyncedVersion => 'Keep synced version';

  @override
  String get reviewUseMyVersion => 'Use my version';

  @override
  String get reviewUseMyChoice => 'Use my choice';

  @override
  String get reviewArchiveThis => 'Archive this habit';

  @override
  String get reviewRestoreThis => 'Restore this habit';

  @override
  String reviewFieldLine(String label, String value) {
    return '$label: $value';
  }

  @override
  String get reviewFieldName => 'Name';

  @override
  String get reviewFieldCategory => 'Category';

  @override
  String get reviewFieldTarget => 'Target';

  @override
  String get reviewFieldUnit => 'Unit';

  @override
  String get reviewFieldSchedule => 'Schedule';

  @override
  String get reviewNoUnit => 'No unit';

  @override
  String get reviewDiscardChange => 'Discard this change';

  @override
  String get reviewKeptSynced => 'Kept the synced value.';

  @override
  String get reviewUsedMine => 'Your choice is saved on this device and will sync.';

  @override
  String get reviewGone => 'This change no longer needs a look.';

  @override
  String reviewCardSpoken(String title, String value, String line) {
    return '$title: $value. $line';
  }

  @override
  String get queueReview => 'Review';

  @override
  String get queueChangeIncrement => 'Progress added';

  @override
  String get queueChangeHabitEdit => 'Habit edited';

  @override
  String get queueChangeArchived => 'Archived';

  @override
  String get queueChangeRestored => 'Restored';

  @override
  String get reasonHabitArchived => 'This habit was archived on another device.';

  @override
  String reviewEditedAtOnly(String time) {
    return 'Edited at $time';
  }

  @override
  String get reviewDiscarded => 'Discarded this change.';

  @override
  String reviewAddedAt(String time) {
    return 'Added at $time';
  }

  @override
  String reviewEditedAtFirst(String time) {
    return 'Edited at $time · first entry of the day';
  }

  @override
  String reviewRemovedAtFirst(String time) {
    return 'Removed at $time · first entry of the day';
  }

  @override
  String todayRewardLine(int xp, int level) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$xpString XP · Level $level';
  }

  @override
  String todayRewardLineLabel(int xp, int level) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$xpString XP, Level $level';
  }

  @override
  String profileRewardLine(String place, int level, int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return '$place · Level $level · $xpString XP';
  }

  @override
  String profileRewardLineNoPlace(int level, int xp) {
    final intl.NumberFormat xpNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String xpString = xpNumberFormat.format(xp);

    return 'Level $level · $xpString XP';
  }
}
