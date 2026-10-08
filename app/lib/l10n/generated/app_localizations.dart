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

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navHabits.
  ///
  /// In en, this message translates to:
  /// **'Habits'**
  String get navHabits;

  /// No description provided for @navInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navLater.
  ///
  /// In en, this message translates to:
  /// **'{tab}, arrives in a later update'**
  String navLater(String tab);

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your habits'**
  String get libraryTitle;

  /// No description provided for @librarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{active, plural, =1{1 active routine} other{{active} active routines}} · {archived} archived'**
  String librarySubtitle(int active, int archived);

  /// No description provided for @librarySearch.
  ///
  /// In en, this message translates to:
  /// **'Search your habits'**
  String get librarySearch;

  /// No description provided for @libraryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryAll;

  /// No description provided for @libraryCreate.
  ///
  /// In en, this message translates to:
  /// **'Create a habit'**
  String get libraryCreate;

  /// No description provided for @libraryNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No habits match your search.'**
  String get libraryNoMatch;

  /// No description provided for @libraryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open {name}. {detail}'**
  String libraryOpen(String name, String detail);

  /// No description provided for @typeYesNo.
  ///
  /// In en, this message translates to:
  /// **'Yes / no'**
  String get typeYesNo;

  /// No description provided for @typeQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get typeQuantity;

  /// No description provided for @typeDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get typeDuration;

  /// No description provided for @typeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Needs an app update'**
  String get typeUnknown;

  /// No description provided for @freqDaily.
  ///
  /// In en, this message translates to:
  /// **'daily'**
  String get freqDaily;

  /// No description provided for @freqWeekdays.
  ///
  /// In en, this message translates to:
  /// **'weekdays'**
  String get freqWeekdays;

  /// No description provided for @freqWeekly.
  ///
  /// In en, this message translates to:
  /// **'{count}× / week'**
  String freqWeekly(int count);

  /// No description provided for @freqInterval.
  ///
  /// In en, this message translates to:
  /// **'every {days} days'**
  String freqInterval(int days);

  /// No description provided for @freqUnknown.
  ///
  /// In en, this message translates to:
  /// **'custom schedule'**
  String get freqUnknown;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(String minutes);

  /// No description provided for @rowDetail.
  ///
  /// In en, this message translates to:
  /// **'{type} · {target} · {frequency}'**
  String rowDetail(String type, String target, String frequency);

  /// No description provided for @rowDetailNoTarget.
  ///
  /// In en, this message translates to:
  /// **'{type} · {frequency}'**
  String rowDetailNoTarget(String type, String frequency);

  /// No description provided for @todayCompletedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed at {time}'**
  String todayCompletedAt(String time);

  /// No description provided for @todayCompletedAtWaiting.
  ///
  /// In en, this message translates to:
  /// **'Completed at {time} · waiting to sync'**
  String todayCompletedAtWaiting(String time);

  /// No description provided for @todayWeek.
  ///
  /// In en, this message translates to:
  /// **'{done} of {target} this week · counted on this device'**
  String todayWeek(int done, int target);

  /// No description provided for @todayOpenDetail.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String todayOpenDetail(String name);

  /// No description provided for @askZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Your device is now in {zone}. Use it for your days?'**
  String askZoneTitle(String zone);

  /// No description provided for @askZoneBody.
  ///
  /// In en, this message translates to:
  /// **'The change applies from the start of your next day.'**
  String get askZoneBody;

  /// No description provided for @askZoneUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get askZoneUse;

  /// No description provided for @askZoneNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get askZoneNotNow;

  /// No description provided for @detailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{schedule} · {category}'**
  String detailSubtitle(String schedule, String category);

  /// No description provided for @categoryMindfulness.
  ///
  /// In en, this message translates to:
  /// **'Mindfulness'**
  String get categoryMindfulness;

  /// No description provided for @statDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String statDays(int count);

  /// No description provided for @statWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String statWeeks(int count);

  /// No description provided for @statPeriods.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 time} other{{count} times}}'**
  String statPeriods(int count);

  /// No description provided for @statNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get statNotYet;

  /// No description provided for @statCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get statCurrent;

  /// No description provided for @statCurrentAsOf.
  ///
  /// In en, this message translates to:
  /// **'Current streak · as of {date}'**
  String statCurrentAsOf(String date);

  /// No description provided for @statBest.
  ///
  /// In en, this message translates to:
  /// **'Best streak'**
  String get statBest;

  /// No description provided for @statToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statToday;

  /// No description provided for @statTodayDone.
  ///
  /// In en, this message translates to:
  /// **'Today · done'**
  String get statTodayDone;

  /// No description provided for @statDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statDone;

  /// No description provided for @heatmapMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get heatmapMonth;

  /// No description provided for @heatmapPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get heatmapPrevious;

  /// No description provided for @heatmapNext.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get heatmapNext;

  /// No description provided for @legendComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get legendComplete;

  /// No description provided for @legendProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get legendProtected;

  /// No description provided for @legendMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed (–)'**
  String get legendMissed;

  /// No description provided for @legendNotDue.
  ///
  /// In en, this message translates to:
  /// **'Not due (outline)'**
  String get legendNotDue;

  /// No description provided for @statusComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get statusComplete;

  /// No description provided for @statusProtected.
  ///
  /// In en, this message translates to:
  /// **'Protected'**
  String get statusProtected;

  /// No description provided for @statusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusMissed;

  /// No description provided for @statusNotDue.
  ///
  /// In en, this message translates to:
  /// **'Not due'**
  String get statusNotDue;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get statusUpcoming;

  /// No description provided for @cellLabel.
  ///
  /// In en, this message translates to:
  /// **'{date}, {status}'**
  String cellLabel(String date, String status);

  /// No description provided for @cellLabelProvisional.
  ///
  /// In en, this message translates to:
  /// **'{date}, {status}, saved on this device'**
  String cellLabelProvisional(String date, String status);

  /// No description provided for @streakProtected.
  ///
  /// In en, this message translates to:
  /// **'Your streak includes {count, plural, =1{1 protected day} other{{count} protected days}}.'**
  String streakProtected(int count);

  /// No description provided for @streakPause.
  ///
  /// In en, this message translates to:
  /// **'A missed day is a pause, not a failure.'**
  String get streakPause;

  /// No description provided for @olderNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Older history needs a connection'**
  String get olderNeedsConnection;

  /// No description provided for @olderLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading older history…'**
  String get olderLoading;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your history'**
  String get historyTitle;

  /// No description provided for @historySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check-ins stay editable and traceable.'**
  String get historySubtitle;

  /// No description provided for @historyTabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyTabToday;

  /// No description provided for @historyTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTabHistory;

  /// No description provided for @historyRow.
  ///
  /// In en, this message translates to:
  /// **'{date} · {name}'**
  String historyRow(String date, String name);

  /// No description provided for @historyRowDetail.
  ///
  /// In en, this message translates to:
  /// **'{value} · completed at {time}'**
  String historyRowDetail(String value, String time);

  /// No description provided for @historyRowWaiting.
  ///
  /// In en, this message translates to:
  /// **'{value} · waiting to sync'**
  String historyRowWaiting(String value);

  /// No description provided for @historyEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get historyEdit;

  /// No description provided for @historyEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit the check-in for {date}'**
  String historyEditLabel(String date);

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No check-ins in the last 30 days.'**
  String get historyEmpty;

  /// No description provided for @historyEmptyToday.
  ///
  /// In en, this message translates to:
  /// **'No check-in yet today.'**
  String get historyEmptyToday;

  /// No description provided for @historyAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a past check-in'**
  String get historyAddTitle;

  /// No description provided for @historyDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Local habit date'**
  String get historyDateLabel;

  /// No description provided for @historyDateChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose calendar day'**
  String get historyDateChoose;

  /// No description provided for @historyValueCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get historyValueCheckIn;

  /// No description provided for @historyValueDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get historyValueDone;

  /// No description provided for @historyValueNotDone.
  ///
  /// In en, this message translates to:
  /// **'Not done'**
  String get historyValueNotDone;

  /// No description provided for @historyValueDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get historyValueDuration;

  /// No description provided for @historyValueAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get historyValueAmount;

  /// No description provided for @historyMinutesUnit.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get historyMinutesUnit;

  /// No description provided for @historyTarget.
  ///
  /// In en, this message translates to:
  /// **'Target that day: {target}'**
  String historyTarget(String target);

  /// No description provided for @historyNote.
  ///
  /// In en, this message translates to:
  /// **'Uses your habit timezone for that date. Streak and freeze changes are reconciled after syncing.'**
  String get historyNote;

  /// No description provided for @historySave.
  ///
  /// In en, this message translates to:
  /// **'Save past check-in'**
  String get historySave;

  /// No description provided for @historySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. It syncs when you are online.'**
  String get historySaved;

  /// No description provided for @historyRefuseFuture.
  ///
  /// In en, this message translates to:
  /// **'That date has not started yet in your habit calendar.'**
  String get historyRefuseFuture;

  /// No description provided for @historyRefuseOld.
  ///
  /// In en, this message translates to:
  /// **'Past check-ins can go back 30 days.'**
  String get historyRefuseOld;

  /// No description provided for @historyRefuseInactive.
  ///
  /// In en, this message translates to:
  /// **'This habit was not active on that date.'**
  String get historyRefuseInactive;

  /// No description provided for @historyValueInvalidMinutes.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number of minutes, like 10.'**
  String get historyValueInvalidMinutes;

  /// No description provided for @historyValueInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount, like 1.5.'**
  String get historyValueInvalidAmount;

  /// No description provided for @setupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get reminders that respect your routine.'**
  String get setupSubtitle;

  /// No description provided for @setupEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get setupEdit;

  /// No description provided for @setupEditZone.
  ///
  /// In en, this message translates to:
  /// **'Edit habit timezone'**
  String get setupEditZone;

  /// No description provided for @setupFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow device timezone'**
  String get setupFollow;

  /// No description provided for @setupFollowNote.
  ///
  /// In en, this message translates to:
  /// **'Ask before changing your habit calendar'**
  String get setupFollowNote;

  /// No description provided for @setupQueued.
  ///
  /// In en, this message translates to:
  /// **'{zone} · waiting to sync'**
  String setupQueued(String zone);

  /// No description provided for @setupPending.
  ///
  /// In en, this message translates to:
  /// **'{zone} · changes at the start of your next day ({time})'**
  String setupPending(String zone, String time);

  /// No description provided for @setupQueuedProblem.
  ///
  /// In en, this message translates to:
  /// **'This change needs a look. Open Sync to review it.'**
  String get setupQueuedProblem;

  /// No description provided for @setupNextDay.
  ///
  /// In en, this message translates to:
  /// **'A new timezone applies from the start of your next day.'**
  String get setupNextDay;

  /// No description provided for @zonePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a timezone'**
  String get zonePickerTitle;

  /// No description provided for @zoneSearch.
  ///
  /// In en, this message translates to:
  /// **'Search timezones'**
  String get zoneSearch;

  /// No description provided for @zoneNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No timezones match.'**
  String get zoneNoMatch;

  /// No description provided for @zoneRow.
  ///
  /// In en, this message translates to:
  /// **'{city}, {offset}'**
  String zoneRow(String city, String offset);

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
