import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Habit System'**
  String get appTitle;

  /// No description provided for @statusTitle.
  ///
  /// In en, this message translates to:
  /// **'Server connection'**
  String get statusTitle;

  /// No description provided for @statusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Checks that this device can reach the habit service.'**
  String get statusSubtitle;

  /// No description provided for @statusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the connection…'**
  String get statusChecking;

  /// No description provided for @statusOnline.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusOffline;

  /// No description provided for @statusServerTime.
  ///
  /// In en, this message translates to:
  /// **'Server time (UTC)'**
  String get statusServerTime;

  /// No description provided for @statusServerTimeLocal.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get statusServerTimeLocal;

  /// No description provided for @statusRequestId.
  ///
  /// In en, this message translates to:
  /// **'Request ID'**
  String get statusRequestId;

  /// No description provided for @statusCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get statusCheckAgain;

  /// No description provided for @statusOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Logging never waits for the network. Changes stay on this device until they sync.'**
  String get statusOfflineHint;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get fieldName;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @errorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an email address, like name@example.com.'**
  String get errorEmailInvalid;

  /// No description provided for @errorPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 12 characters.'**
  String get errorPasswordShort;

  /// No description provided for @errorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get errorNameRequired;

  /// No description provided for @errorNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 80 characters or fewer.'**
  String get errorNameTooLong;

  /// No description provided for @errorRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is needed.'**
  String get errorRequired;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts for now. Try again in a minute.'**
  String get errorRateLimited;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorGeneric;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get signInTitle;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your routines are right where you left them.'**
  String get signInSubtitle;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @signInPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Private by default'**
  String get signInPrivateTitle;

  /// No description provided for @signInPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Your habits and history belong to you. Export them whenever you need.'**
  String get signInPrivateBody;

  /// No description provided for @signInCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get signInCreateAccount;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Make room for you'**
  String get createAccountTitle;

  /// No description provided for @createAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A few details, then your first habit.'**
  String get createAccountSubtitle;

  /// No description provided for @createAccountPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'Use at least 12 characters.'**
  String get createAccountPasswordHelper;

  /// No description provided for @createAccountTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms and Privacy Policy.'**
  String get createAccountTerms;

  /// No description provided for @createAccountTermsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Agree to the Terms and Privacy Policy to continue.'**
  String get createAccountTermsNeeded;

  /// No description provided for @createAccountNoPressureTitle.
  ///
  /// In en, this message translates to:
  /// **'No pressure. No public profile.'**
  String get createAccountNoPressureTitle;

  /// No description provided for @createAccountNoPressureBody.
  ///
  /// In en, this message translates to:
  /// **'Start small. You can change your routines any time.'**
  String get createAccountNoPressureBody;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @createAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get createAccountSignIn;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Your day, your time'**
  String get setupTitle;

  /// No description provided for @setupZoneNote.
  ///
  /// In en, this message translates to:
  /// **'Habit days use your saved timezone. Past check-ins keep their original dates.'**
  String get setupZoneNote;

  /// No description provided for @setupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get setupContinue;

  /// No description provided for @setupZoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Habit timezone {zone}'**
  String setupZoneLabel(String zone);

  /// No description provided for @todayGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String todayGreetingMorning(String name);

  /// No description provided for @todayGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String todayGreetingAfternoon(String name);

  /// No description provided for @todayGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String todayGreetingEvening(String name);

  /// No description provided for @todayGreetingPlain.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayGreetingPlain;

  /// No description provided for @todaySummary.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} habits complete'**
  String todaySummary(int done, int total);

  /// No description provided for @todaySummaryProvisional.
  ///
  /// In en, this message translates to:
  /// **'Includes changes waiting to sync.'**
  String get todaySummaryProvisional;

  /// No description provided for @todayOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening your habits…'**
  String get todayOpening;

  /// No description provided for @todayLoadError.
  ///
  /// In en, this message translates to:
  /// **'Your habits could not be shown. Try again.'**
  String get todayLoadError;

  /// No description provided for @todayRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get todayRetry;

  /// No description provided for @todayDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get todayDone;

  /// No description provided for @todayDoneWaiting.
  ///
  /// In en, this message translates to:
  /// **'Done · waiting to sync'**
  String get todayDoneWaiting;

  /// No description provided for @todayNotDone.
  ///
  /// In en, this message translates to:
  /// **'Tap to check in'**
  String get todayNotDone;

  /// No description provided for @todayNotDoneWaiting.
  ///
  /// In en, this message translates to:
  /// **'Not checked in · waiting to sync'**
  String get todayNotDoneWaiting;

  /// No description provided for @todayNeedsLook.
  ///
  /// In en, this message translates to:
  /// **'Needs a look · tap to review'**
  String get todayNeedsLook;

  /// No description provided for @todayUnknownType.
  ///
  /// In en, this message translates to:
  /// **'Update the app to log this habit.'**
  String get todayUnknownType;

  /// No description provided for @todayOtherType.
  ///
  /// In en, this message translates to:
  /// **'Logging this kind of habit arrives in a later update.'**
  String get todayOtherType;

  /// No description provided for @todayNewHabitWaiting.
  ///
  /// In en, this message translates to:
  /// **'New · waiting to sync'**
  String get todayNewHabitWaiting;

  /// No description provided for @todayCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in {name}'**
  String todayCheckIn(String name);

  /// No description provided for @todayUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo check-in for {name}'**
  String todayUndo(String name);

  /// No description provided for @todayCreateHabit.
  ///
  /// In en, this message translates to:
  /// **'Create a habit'**
  String get todayCreateHabit;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your first step'**
  String get emptyTitle;

  /// No description provided for @emptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'One small routine is a great place to start.'**
  String get emptySubtitle;

  /// No description provided for @emptyHeading.
  ///
  /// In en, this message translates to:
  /// **'No habits yet'**
  String get emptyHeading;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try a glass of water, five minutes of reading, or a moment to breathe. Start with one.'**
  String get emptyBody;

  /// No description provided for @emptyButton.
  ///
  /// In en, this message translates to:
  /// **'Create your first habit'**
  String get emptyButton;

  /// No description provided for @chipSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get chipSynced;

  /// No description provided for @chipSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get chipSyncing;

  /// No description provided for @chipOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chipOffline;

  /// No description provided for @chipWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String chipWaiting(int count);

  /// No description provided for @chipNeedsLook.
  ///
  /// In en, this message translates to:
  /// **'Needs a look'**
  String get chipNeedsLook;

  /// No description provided for @chipPaused.
  ///
  /// In en, this message translates to:
  /// **'Sync paused'**
  String get chipPaused;

  /// No description provided for @chipNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get chipNotYet;

  /// No description provided for @chipOpenQueue.
  ///
  /// In en, this message translates to:
  /// **'Sync status: {status}. Open sync details.'**
  String chipOpenQueue(String status);

  /// No description provided for @resolveTitle.
  ///
  /// In en, this message translates to:
  /// **'This check-in needs a look'**
  String get resolveTitle;

  /// No description provided for @resolveDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard my change'**
  String get resolveDiscard;

  /// No description provided for @resolveOpenQueue.
  ///
  /// In en, this message translates to:
  /// **'Open sync details'**
  String get resolveOpenQueue;

  /// No description provided for @discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this change?'**
  String get discardTitle;

  /// No description provided for @discardBody.
  ///
  /// In en, this message translates to:
  /// **'It stays recorded on this device but will not be sent.'**
  String get discardBody;

  /// No description provided for @discardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reasonVersionConflict.
  ///
  /// In en, this message translates to:
  /// **'It changed on another device first.'**
  String get reasonVersionConflict;

  /// No description provided for @reasonResourceDeleted.
  ///
  /// In en, this message translates to:
  /// **'It was removed on another device first.'**
  String get reasonResourceDeleted;

  /// No description provided for @reasonParentRejected.
  ///
  /// In en, this message translates to:
  /// **'Its habit was not saved.'**
  String get reasonParentRejected;

  /// No description provided for @reasonFutureEvent.
  ///
  /// In en, this message translates to:
  /// **'This device\'s clock was ahead when it was saved.'**
  String get reasonFutureEvent;

  /// No description provided for @reasonGeneric.
  ///
  /// In en, this message translates to:
  /// **'The server could not accept it.'**
  String get reasonGeneric;

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device'**
  String get queueTitle;

  /// No description provided for @queueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can keep logging without a connection.'**
  String get queueSubtitle;

  /// No description provided for @queuePending.
  ///
  /// In en, this message translates to:
  /// **'Pending check-ins'**
  String get queuePending;

  /// No description provided for @queueLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get queueLastSynced;

  /// No description provided for @queueNever.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get queueNever;

  /// No description provided for @queueOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a connection'**
  String get queueOfflineTitle;

  /// No description provided for @queueOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Your outbox stays safe until each change is acknowledged.'**
  String get queueOfflineBody;

  /// No description provided for @queuePausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync is paused'**
  String get queuePausedTitle;

  /// No description provided for @queuePausedBody.
  ///
  /// In en, this message translates to:
  /// **'The server is not accepting sync requests from this app ({code}). Your changes stay on this device. Updating the app may help.'**
  String queuePausedBody(String code);

  /// No description provided for @queueSyncedTitle.
  ///
  /// In en, this message translates to:
  /// **'Everything is synced'**
  String get queueSyncedTitle;

  /// No description provided for @queueSyncedBody.
  ///
  /// In en, this message translates to:
  /// **'Changes you make now are saved here first, then sent.'**
  String get queueSyncedBody;

  /// No description provided for @queueSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get queueSyncNow;

  /// No description provided for @queueTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get queueTryAgain;

  /// No description provided for @queueFooter.
  ///
  /// In en, this message translates to:
  /// **'Duplicate retries never duplicate a check-in.'**
  String get queueFooter;

  /// No description provided for @queueStateQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get queueStateQueued;

  /// No description provided for @queueStateSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get queueStateSending;

  /// No description provided for @queueStateRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying later'**
  String get queueStateRetrying;

  /// No description provided for @queueStateWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for its habit'**
  String get queueStateWaiting;

  /// No description provided for @queueStateNeedsLook.
  ///
  /// In en, this message translates to:
  /// **'Needs a look'**
  String get queueStateNeedsLook;

  /// No description provided for @queueChangeNewHabit.
  ///
  /// In en, this message translates to:
  /// **'New habit'**
  String get queueChangeNewHabit;

  /// No description provided for @queueChangeCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get queueChangeCheckIn;

  /// No description provided for @queueChangeUndo.
  ///
  /// In en, this message translates to:
  /// **'Check-in undone'**
  String get queueChangeUndo;

  /// No description provided for @queueChangeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get queueChangeRemoved;

  /// No description provided for @queueChangeOther.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get queueChangeOther;

  /// No description provided for @queueItemTitle.
  ///
  /// In en, this message translates to:
  /// **'{habit} · {change}'**
  String queueItemTitle(String habit, String change);

  /// No description provided for @queueItemWhen.
  ///
  /// In en, this message translates to:
  /// **'{when} · waiting to sync'**
  String queueItemWhen(String when);

  /// No description provided for @queueUnnamedHabit.
  ///
  /// In en, this message translates to:
  /// **'A habit'**
  String get queueUnnamedHabit;

  /// No description provided for @newHabitTitle.
  ///
  /// In en, this message translates to:
  /// **'A new routine'**
  String get newHabitTitle;

  /// No description provided for @newHabitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose something small and specific.'**
  String get newHabitSubtitle;

  /// No description provided for @newHabitName.
  ///
  /// In en, this message translates to:
  /// **'Habit name'**
  String get newHabitName;

  /// No description provided for @newHabitNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 100 characters or fewer.'**
  String get newHabitNameTooLong;

  /// No description provided for @newHabitType.
  ///
  /// In en, this message translates to:
  /// **'Habit type'**
  String get newHabitType;

  /// No description provided for @newHabitTypeYesNo.
  ///
  /// In en, this message translates to:
  /// **'Yes / no'**
  String get newHabitTypeYesNo;

  /// No description provided for @newHabitCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get newHabitCategory;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categoryMindful.
  ///
  /// In en, this message translates to:
  /// **'Mindful'**
  String get categoryMindful;

  /// No description provided for @categoryLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get categoryLearning;

  /// No description provided for @newHabitSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get newHabitSchedule;

  /// No description provided for @newHabitDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get newHabitDaily;

  /// No description provided for @newHabitCreate.
  ///
  /// In en, this message translates to:
  /// **'Create habit'**
  String get newHabitCreate;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
