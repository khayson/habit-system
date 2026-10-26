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

  /// No description provided for @legalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get legalTerms;

  /// No description provided for @legalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacy;

  /// No description provided for @legalOpensInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Opens in your browser'**
  String get legalOpensInBrowser;

  /// No description provided for @legalOpenFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'The page didn\'t open here'**
  String get legalOpenFailedTitle;

  /// No description provided for @legalOpenFailedBody.
  ///
  /// In en, this message translates to:
  /// **'You can copy the link and open it in any browser.'**
  String get legalOpenFailedBody;

  /// No description provided for @legalCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get legalCopyLink;

  /// No description provided for @legalLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get legalLinkCopied;

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
  /// **'Includes changes waiting to sync. Rewards update after syncing.'**
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

  /// A56: tooltip on the Today circle of an amount or duration habit.
  ///
  /// In en, this message translates to:
  /// **'Add progress to {name}'**
  String todayDotAdd(String name);

  /// A56: tooltip on the Today circle of a finished amount or duration habit.
  ///
  /// In en, this message translates to:
  /// **'{name} is done for today'**
  String todayDoneTip(String name);

  /// A56: toast when the circle of a finished amount habit is tapped.
  ///
  /// In en, this message translates to:
  /// **'{name} is done for today. Open it to change the amount.'**
  String todayDoneToast(String name);

  /// A57: small tag above a notice Khay Studios published.
  ///
  /// In en, this message translates to:
  /// **'From the Habit team'**
  String get carouselNoticeTag;

  /// A57: small tag above a built-in tip card.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get carouselTipTag;

  /// A57: a carousel page dot, for TalkBack.
  ///
  /// In en, this message translates to:
  /// **'Show card {n} of {total}'**
  String carouselShow(int n, int total);

  /// A57: the ✕ on a notice or tip card.
  ///
  /// In en, this message translates to:
  /// **'Dismiss {title}'**
  String carouselDismiss(String title);

  /// A57: built-in tip card title.
  ///
  /// In en, this message translates to:
  /// **'Tap the circle'**
  String get tipCircleTitle;

  /// A57: built-in tip card body.
  ///
  /// In en, this message translates to:
  /// **'The circle beside a habit checks it in, or adds progress to an amount.'**
  String get tipCircleBody;

  /// A57: built-in tip card title.
  ///
  /// In en, this message translates to:
  /// **'Repeat on your days'**
  String get tipDaysTitle;

  /// A57: built-in tip card body.
  ///
  /// In en, this message translates to:
  /// **'A habit can repeat on the days you choose. Pick them with the round day chips.'**
  String get tipDaysBody;

  /// A56: the heading above Today's habits.
  ///
  /// In en, this message translates to:
  /// **'Daily routine'**
  String get todayRoutine;

  /// No description provided for @todaySeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get todaySeeAll;

  /// A56: the server-confirmed current streak on a Today row.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No streak yet} =1{Streak 1 day} other{Streak {count} days}}'**
  String todayStreak(int count);

  /// No description provided for @todayWeekSpoken.
  ///
  /// In en, this message translates to:
  /// **'This week, {start} to {end}. Today is {today}.'**
  String todayWeekSpoken(String start, String end, String today);

  /// No description provided for @todayReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a reminder'**
  String get todayReminderTitle;

  /// No description provided for @todayReminderBody.
  ///
  /// In en, this message translates to:
  /// **'A gentle nudge at the time you choose helps a routine stick.'**
  String get todayReminderBody;

  /// No description provided for @todayReminderAction.
  ///
  /// In en, this message translates to:
  /// **'Set now'**
  String get todayReminderAction;

  /// No description provided for @todayAvatarHint.
  ///
  /// In en, this message translates to:
  /// **'Opens your profile'**
  String get todayAvatarHint;

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

  /// A51: a queued change for a habit another device deleted; Discard only.
  ///
  /// In en, this message translates to:
  /// **'This habit was deleted on another device.'**
  String get reasonHabitDeleted;

  /// No description provided for @swipeArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get swipeArchive;

  /// No description provided for @swipeRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get swipeRestore;

  /// A51: what a left swipe reveals on 07 and 22, and the screen-reader action. It opens the confirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get swipeDelete;

  /// No description provided for @archivedSnack.
  ///
  /// In en, this message translates to:
  /// **'Archived {name}.'**
  String archivedSnack(String name);

  /// No description provided for @restoredSnack.
  ///
  /// In en, this message translates to:
  /// **'Restored {name}.'**
  String restoredSnack(String name);

  /// No description provided for @snackUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get snackUndo;

  /// A53: the Icon row on create and edit habit.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get habitIconRow;

  /// No description provided for @iconPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an icon'**
  String get iconPickerTitle;

  /// No description provided for @iconPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search icons'**
  String get iconPickerSearch;

  /// No description provided for @iconPickerUseCategory.
  ///
  /// In en, this message translates to:
  /// **'Use the category\'s icon'**
  String get iconPickerUseCategory;

  /// No description provided for @iconPickerSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get iconPickerSuggested;

  /// No description provided for @iconPickerAll.
  ///
  /// In en, this message translates to:
  /// **'All icons'**
  String get iconPickerAll;

  /// No description provided for @iconPickerNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No icon matches \"{query}\".'**
  String iconPickerNoMatch(String query);

  /// 6.7 review: the toast after a habit edit is saved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved.'**
  String get editSaved;

  /// A54: the server needs a newer app build.
  ///
  /// In en, this message translates to:
  /// **'A new version is ready'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'This version can no longer sync. Your habits are safe on this phone and sync again after you update.'**
  String get updateBody;

  /// No description provided for @updateButton.
  ///
  /// In en, this message translates to:
  /// **'Get the update'**
  String get updateButton;

  /// A56: the white-circle ✕ that closes a screen.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// A52: tooltip and label of the close button on a toast.
  ///
  /// In en, this message translates to:
  /// **'Close message'**
  String get toastClose;

  /// No description provided for @deleteHabitTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteHabitTitle(String name);

  /// No description provided for @deleteHabitBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the habit, its check-ins, notes and reminders from all your devices. XP you earned stays.'**
  String get deleteHabitBody;

  /// No description provided for @deleteHabitKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep habit'**
  String get deleteHabitKeep;

  /// No description provided for @deleteHabitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete habit'**
  String get deleteHabitConfirm;

  /// No description provided for @deletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Deleted {name}.'**
  String deletedSnack(String name);

  /// No description provided for @detailDeleteHabit.
  ///
  /// In en, this message translates to:
  /// **'Delete habit'**
  String get detailDeleteHabit;

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
  /// **'Your outbox stays safe until each change is acknowledged. Rewards update after syncing.'**
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

  /// No description provided for @queueYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get queueYourProfile;

  /// No description provided for @queueChangeProfile.
  ///
  /// In en, this message translates to:
  /// **'Name and location'**
  String get queueChangeProfile;

  /// No description provided for @queueChangeTimezone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get queueChangeTimezone;

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

  /// No description provided for @categoryProductivity.
  ///
  /// In en, this message translates to:
  /// **'Productivity'**
  String get categoryProductivity;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// A56: label over the seven round weekday chips on New and Edit habit.
  ///
  /// In en, this message translates to:
  /// **'Repeat days'**
  String get newHabitRepeatDays;

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

  /// No description provided for @heatmapProvisional.
  ///
  /// In en, this message translates to:
  /// **'Some days are counted on this device and are confirmed after syncing.'**
  String get heatmapProvisional;

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

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'A gentle reminder for today.'**
  String get reminderBody;

  /// No description provided for @reminderTitleHidden.
  ///
  /// In en, this message translates to:
  /// **'A habit reminder'**
  String get reminderTitleHidden;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your space'**
  String get profileTitle;

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preferences that follow your life.'**
  String get profileSubtitle;

  /// No description provided for @profileLocationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add your city and country'**
  String get profileLocationEmpty;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEdit;

  /// No description provided for @avatarLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile photo of {name}'**
  String avatarLabel(String name);

  /// No description provided for @avatarChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Change the profile photo'**
  String get avatarChangeHint;

  /// No description provided for @photoSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get photoSheetTitle;

  /// No description provided for @photoChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get photoChoose;

  /// No description provided for @photoTake.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photoTake;

  /// No description provided for @photoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get photoRemove;

  /// No description provided for @photoCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop photo'**
  String get photoCropTitle;

  /// No description provided for @photoRejected.
  ///
  /// In en, this message translates to:
  /// **'That photo couldn\'t be used. Choose another.'**
  String get photoRejected;

  /// No description provided for @photoWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to upload'**
  String get photoWaiting;

  /// No description provided for @profileEditQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get profileEditQueued;

  /// No description provided for @profileTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get profileTimezone;

  /// No description provided for @profileTimezoneEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit the timezone'**
  String get profileTimezoneEditLabel;

  /// No description provided for @profileReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get profileReminders;

  /// No description provided for @profileRemindersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reminders} =1{1 reminder} other{{count} reminders}}'**
  String profileRemindersCount(int count);

  /// No description provided for @profileNotificationsOn.
  ///
  /// In en, this message translates to:
  /// **'notifications on'**
  String get profileNotificationsOn;

  /// No description provided for @profileNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'off in device settings'**
  String get profileNotificationsOff;

  /// No description provided for @profileNotificationsUnknown.
  ///
  /// In en, this message translates to:
  /// **'notifications not allowed yet'**
  String get profileNotificationsUnknown;

  /// No description provided for @profileRemindersLine.
  ///
  /// In en, this message translates to:
  /// **'{count} · {permission}'**
  String profileRemindersLine(String count, String permission);

  /// No description provided for @remindersSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersSheetTitle;

  /// No description provided for @remindersSheetEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet. Add one from a habit.'**
  String get remindersSheetEmpty;

  /// No description provided for @remindersSheetHabitLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminders for {habit}'**
  String remindersSheetHabitLabel(String habit);

  /// No description provided for @hideNamesTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide habit names in notifications'**
  String get hideNamesTitle;

  /// No description provided for @hideNamesBody.
  ///
  /// In en, this message translates to:
  /// **'Reminders on the lock screen won\'t say which habit they are for.'**
  String get hideNamesBody;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String signedInAs(String email);

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutUnsynced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change hasn\'t synced yet. It stays saved on this phone and uploads the next time you sign in here.} other{{count} changes haven\'t synced yet. They stay saved on this phone and upload the next time you sign in here.}}'**
  String signOutUnsynced(int count);

  /// No description provided for @profileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditTitle;

  /// No description provided for @fieldCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get fieldCity;

  /// No description provided for @fieldCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get fieldCountry;

  /// No description provided for @countryNone.
  ///
  /// In en, this message translates to:
  /// **'No country'**
  String get countryNone;

  /// No description provided for @countrySearch.
  ///
  /// In en, this message translates to:
  /// **'Search countries'**
  String get countrySearch;

  /// No description provided for @countryPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryPickerTitle;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @errorCityTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 60 characters or fewer.'**
  String get errorCityTooLong;

  /// No description provided for @photoPickFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open your photos. You can allow access in your device settings.'**
  String get photoPickFailed;

  /// No description provided for @photoAddFailed.
  ///
  /// In en, this message translates to:
  /// **'That photo couldn\'t be added. Try another.'**
  String get photoAddFailed;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save that. Try again.'**
  String get saveFailed;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Local reminders'**
  String get remindersTitle;

  /// No description provided for @remindersNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Not allowed yet'**
  String get remindersNotAllowed;

  /// No description provided for @remindersAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get remindersAllowed;

  /// No description provided for @remindersOff.
  ///
  /// In en, this message translates to:
  /// **'Off in device settings'**
  String get remindersOff;

  /// No description provided for @remindersAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get remindersAllow;

  /// No description provided for @remindersOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get remindersOpenSettings;

  /// No description provided for @remindersOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders work offline'**
  String get remindersOfflineTitle;

  /// No description provided for @remindersOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Delivery also depends on device permissions and battery settings. You can skip this for now.'**
  String get remindersOfflineBody;

  /// No description provided for @remindersLater.
  ///
  /// In en, this message translates to:
  /// **'Set up reminders later'**
  String get remindersLater;

  /// No description provided for @reminderEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Gentle reminders'**
  String get reminderEditorTitle;

  /// No description provided for @reminderEditorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{habit} · notifications stay on your device.'**
  String reminderEditorSubtitle(String habit);

  /// No description provided for @reminderNewHabit.
  ///
  /// In en, this message translates to:
  /// **'Your new habit'**
  String get reminderNewHabit;

  /// No description provided for @reminderDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get reminderDeniedTitle;

  /// No description provided for @reminderDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications in device settings before these reminders can appear.'**
  String get reminderDeniedBody;

  /// No description provided for @reminderOpenDeviceSettings.
  ///
  /// In en, this message translates to:
  /// **'Open device settings'**
  String get reminderOpenDeviceSettings;

  /// No description provided for @reminderAskTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications are not allowed yet'**
  String get reminderAskTitle;

  /// No description provided for @reminderAskBody.
  ///
  /// In en, this message translates to:
  /// **'These reminders appear once notifications are allowed on this device.'**
  String get reminderAskBody;

  /// No description provided for @reminderNext.
  ///
  /// In en, this message translates to:
  /// **'Next reminder: {when}'**
  String reminderNext(String when);

  /// No description provided for @reminderEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Repeat every day'**
  String get reminderEveryDay;

  /// No description provided for @reminderWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Repeat on weekdays'**
  String get reminderWeekdays;

  /// No description provided for @reminderOnDays.
  ///
  /// In en, this message translates to:
  /// **'Repeat on {days}'**
  String reminderOnDays(String days);

  /// No description provided for @reminderChooseTime.
  ///
  /// In en, this message translates to:
  /// **'Choose the reminder time, now {time}'**
  String reminderChooseTime(String time);

  /// No description provided for @reminderDayLabel.
  ///
  /// In en, this message translates to:
  /// **'{day}, {state}'**
  String reminderDayLabel(String day, String state);

  /// No description provided for @reminderDayOn.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get reminderDayOn;

  /// No description provided for @reminderDayOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get reminderDayOff;

  /// No description provided for @reminderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Reminder enabled'**
  String get reminderEnabled;

  /// No description provided for @reminderReadyWhenAllowed.
  ///
  /// In en, this message translates to:
  /// **'Ready when permission is allowed'**
  String get reminderReadyWhenAllowed;

  /// No description provided for @reminderOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Arrives on this device'**
  String get reminderOnThisDevice;

  /// No description provided for @reminderOther.
  ///
  /// In en, this message translates to:
  /// **'Other reminders'**
  String get reminderOther;

  /// No description provided for @reminderNote.
  ///
  /// In en, this message translates to:
  /// **'Local reminders do not depend on a network connection. Battery settings may delay delivery.'**
  String get reminderNote;

  /// No description provided for @reminderSave.
  ///
  /// In en, this message translates to:
  /// **'Save reminder'**
  String get reminderSave;

  /// No description provided for @reminderNeedsDay.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one day.'**
  String get reminderNeedsDay;

  /// No description provided for @reminderRow.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderRow;

  /// No description provided for @reminderRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove reminder'**
  String get reminderRemove;

  /// No description provided for @reminderEditAt.
  ///
  /// In en, this message translates to:
  /// **'Edit the reminder at {time}'**
  String reminderEditAt(String time);

  /// No description provided for @reminderSummaryNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get reminderSummaryNone;

  /// No description provided for @reminderSummaryOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get reminderSummaryOff;

  /// No description provided for @reminderSummaryEveryDay.
  ///
  /// In en, this message translates to:
  /// **'every day'**
  String get reminderSummaryEveryDay;

  /// No description provided for @reminderSummaryWeekdays.
  ///
  /// In en, this message translates to:
  /// **'weekdays'**
  String get reminderSummaryWeekdays;

  /// No description provided for @reminderSummary.
  ///
  /// In en, this message translates to:
  /// **'{time} · {days}'**
  String reminderSummary(String time, String days);

  /// No description provided for @reminderRowNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get reminderRowNone;

  /// No description provided for @reminderRowSet.
  ///
  /// In en, this message translates to:
  /// **'{time} · local device time'**
  String reminderRowSet(String time);

  /// No description provided for @targetAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get targetAmount;

  /// No description provided for @targetUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get targetUnit;

  /// No description provided for @targetUnitHint.
  ///
  /// In en, this message translates to:
  /// **'ml, pages'**
  String get targetUnitHint;

  /// No description provided for @targetMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get targetMinutes;

  /// No description provided for @targetMinutesSuffix.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get targetMinutesSuffix;

  /// No description provided for @unknownTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'This habit needs a newer version of the app'**
  String get unknownTypeTitle;

  /// No description provided for @unknownTypeBody.
  ///
  /// In en, this message translates to:
  /// **'Its history is safe. Update the app to change it.'**
  String get unknownTypeBody;

  /// No description provided for @targetErrorRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a daily target.'**
  String get targetErrorRequired;

  /// No description provided for @targetErrorNotNumber.
  ///
  /// In en, this message translates to:
  /// **'Use a number, such as 250 or 1.5.'**
  String get targetErrorNotNumber;

  /// No description provided for @targetErrorTooPrecise.
  ///
  /// In en, this message translates to:
  /// **'Use up to 3 decimal places.'**
  String get targetErrorTooPrecise;

  /// No description provided for @targetErrorNotPositive.
  ///
  /// In en, this message translates to:
  /// **'Use a number above zero.'**
  String get targetErrorNotPositive;

  /// No description provided for @targetErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Use a smaller number.'**
  String get targetErrorTooLarge;

  /// No description provided for @targetErrorUnitRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a unit, such as ml or pages.'**
  String get targetErrorUnitRequired;

  /// No description provided for @targetErrorUnitTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use 24 characters or fewer.'**
  String get targetErrorUnitTooLong;

  /// No description provided for @problemCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a category.'**
  String get problemCategory;

  /// No description provided for @problemUnitNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This habit type doesn\'t use a unit.'**
  String get problemUnitNotAllowed;

  /// No description provided for @problemFrequencyType.
  ///
  /// In en, this message translates to:
  /// **'Choose a schedule.'**
  String get problemFrequencyType;

  /// No description provided for @problemWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one day.'**
  String get problemWeekdays;

  /// No description provided for @problemWeeklyCount.
  ///
  /// In en, this message translates to:
  /// **'Choose between 1 and 7 times.'**
  String get problemWeeklyCount;

  /// No description provided for @problemInterval.
  ///
  /// In en, this message translates to:
  /// **'Choose every 1 to 365 days.'**
  String get problemInterval;

  /// No description provided for @problemIntervalAnchor.
  ///
  /// In en, this message translates to:
  /// **'Choose a start date.'**
  String get problemIntervalAnchor;

  /// No description provided for @freqTitle.
  ///
  /// In en, this message translates to:
  /// **'A flexible schedule'**
  String get freqTitle;

  /// No description provided for @freqSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how often {habit} fits your week.'**
  String freqSubtitle(String habit);

  /// No description provided for @freqSubtitleNoName.
  ///
  /// In en, this message translates to:
  /// **'Choose how often this habit fits your week.'**
  String get freqSubtitleNoName;

  /// No description provided for @freqDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get freqDailyTitle;

  /// No description provided for @freqDailyBody.
  ///
  /// In en, this message translates to:
  /// **'A daily routine'**
  String get freqDailyBody;

  /// No description provided for @freqWeekdaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Specific weekdays'**
  String get freqWeekdaysTitle;

  /// No description provided for @freqWeekdaysBody.
  ///
  /// In en, this message translates to:
  /// **'Pick the days that work for you'**
  String get freqWeekdaysBody;

  /// No description provided for @freqWeeklyTitle.
  ///
  /// In en, this message translates to:
  /// **'Times per week'**
  String get freqWeeklyTitle;

  /// No description provided for @freqWeeklyBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Any 1 day in a local week} other{Any {count} distinct days in a local week}}'**
  String freqWeeklyBody(int count);

  /// No description provided for @freqIntervalTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom interval'**
  String get freqIntervalTitle;

  /// No description provided for @freqIntervalBody.
  ///
  /// In en, this message translates to:
  /// **'Every N days from a start date'**
  String get freqIntervalBody;

  /// No description provided for @freqUse.
  ///
  /// In en, this message translates to:
  /// **'Use this schedule'**
  String get freqUse;

  /// No description provided for @freqSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get freqSelected;

  /// No description provided for @freqNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get freqNotSelected;

  /// No description provided for @freqDailyDetail.
  ///
  /// In en, this message translates to:
  /// **'Each local day counts once'**
  String get freqDailyDetail;

  /// No description provided for @freqWeekdaysDetail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No days chosen yet} =1{1 day each week} other{{count} days each week}}'**
  String freqWeekdaysDetail(int count);

  /// No description provided for @freqWeeklySummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Once each week} other{{count} times each week}}'**
  String freqWeeklySummary(int count);

  /// No description provided for @freqWeeklyDetail.
  ///
  /// In en, this message translates to:
  /// **'Monday–Sunday · each day counts once'**
  String get freqWeeklyDetail;

  /// No description provided for @freqIntervalSummary.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Every day} other{Every {days} days}}'**
  String freqIntervalSummary(int days);

  /// No description provided for @freqIntervalDetail.
  ///
  /// In en, this message translates to:
  /// **'Starting {date}'**
  String freqIntervalDetail(String date);

  /// No description provided for @freqIntervalFrom.
  ///
  /// In en, this message translates to:
  /// **'{schedule} from {date}'**
  String freqIntervalFrom(String schedule, String date);

  /// No description provided for @freqWeekInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'The week is still yours'**
  String get freqWeekInfoTitle;

  /// No description provided for @freqWeekInfoBody.
  ///
  /// In en, this message translates to:
  /// **'An unfinished week is pending, not missed.'**
  String get freqWeekInfoBody;

  /// No description provided for @freqDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get freqDaysLabel;

  /// No description provided for @freqTimesLabel.
  ///
  /// In en, this message translates to:
  /// **'Times per week'**
  String get freqTimesLabel;

  /// No description provided for @freqEveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat every'**
  String get freqEveryLabel;

  /// No description provided for @freqEveryValue.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String freqEveryValue(int days);

  /// No description provided for @freqStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get freqStartDate;

  /// No description provided for @freqChooseStart.
  ///
  /// In en, this message translates to:
  /// **'Choose the start date'**
  String get freqChooseStart;

  /// No description provided for @freqFewer.
  ///
  /// In en, this message translates to:
  /// **'Fewer'**
  String get freqFewer;

  /// No description provided for @freqMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get freqMore;

  /// No description provided for @listAnd.
  ///
  /// In en, this message translates to:
  /// **'{head} and {last}'**
  String listAnd(String head, String last);

  /// No description provided for @newHabitTarget.
  ///
  /// In en, this message translates to:
  /// **'Daily target'**
  String get newHabitTarget;

  /// No description provided for @editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editTitle(String name);

  /// No description provided for @editSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust your routine without losing history.'**
  String get editSubtitle;

  /// No description provided for @editTargetUnit.
  ///
  /// In en, this message translates to:
  /// **'Target and unit'**
  String get editTargetUnit;

  /// No description provided for @editTypeLine.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String editTypeLine(String type);

  /// No description provided for @editTypeNote.
  ///
  /// In en, this message translates to:
  /// **'A habit\'s type can\'t be changed. Start a new habit to try a different one.'**
  String get editTypeNote;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get editCategory;

  /// No description provided for @editReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get editReminders;

  /// No description provided for @editRemindersSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not set} =1{{times}} other{{count} reminders · {times}}}'**
  String editRemindersSummary(int count, String times);

  /// No description provided for @editHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History stays unchanged'**
  String get editHistoryTitle;

  /// No description provided for @editHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'New targets apply from the next eligible period. Past check-ins keep their original target.'**
  String get editHistoryBody;

  /// No description provided for @editSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editSave;

  /// No description provided for @editWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get editWaiting;

  /// No description provided for @editStarts.
  ///
  /// In en, this message translates to:
  /// **'New target starts {date}'**
  String editStarts(String date);

  /// No description provided for @editArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive this habit'**
  String get editArchive;

  /// No description provided for @archiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this habit?'**
  String get archiveTitle;

  /// No description provided for @archiveBody.
  ///
  /// In en, this message translates to:
  /// **'Your history stays. It leaves Today and sends no reminders. You can restore it from Archived routines.'**
  String get archiveBody;

  /// No description provided for @archiveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveConfirm;

  /// No description provided for @archiveNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get archiveNotNow;

  /// No description provided for @editBlockedAttention.
  ///
  /// In en, this message translates to:
  /// **'A change to this habit needs a look before you can edit it.'**
  String get editBlockedAttention;

  /// No description provided for @editBlockedArchived.
  ///
  /// In en, this message translates to:
  /// **'This habit is archived. Restore it from Archived routines to make changes.'**
  String get editBlockedArchived;

  /// No description provided for @editReview.
  ///
  /// In en, this message translates to:
  /// **'Review the change'**
  String get editReview;

  /// No description provided for @editGone.
  ///
  /// In en, this message translates to:
  /// **'This habit is no longer on this device.'**
  String get editGone;

  /// No description provided for @chooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get chooseCategory;

  /// No description provided for @archivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Archived routines'**
  String get archivedTitle;

  /// No description provided for @libraryActive.
  ///
  /// In en, this message translates to:
  /// **'{active, plural, =1{1 active routine} other{{active} active routines}}'**
  String libraryActive(int active);

  /// No description provided for @libraryArchivedLink.
  ///
  /// In en, this message translates to:
  /// **'{archived} archived'**
  String libraryArchivedLink(int archived);

  /// No description provided for @libraryArchivedLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Opens Archived routines'**
  String get libraryArchivedLinkHint;

  /// No description provided for @archivedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Taking a pause keeps your past progress.'**
  String get archivedSubtitle;

  /// No description provided for @archivedRow.
  ///
  /// In en, this message translates to:
  /// **'Archived {date} · {category}'**
  String archivedRow(String date, String category);

  /// No description provided for @archivedRowNoDate.
  ///
  /// In en, this message translates to:
  /// **'Archived · {category}'**
  String archivedRowNoDate(String category);

  /// No description provided for @archivedRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get archivedRestore;

  /// No description provided for @archivedRestoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Restore {name}'**
  String archivedRestoreLabel(String name);

  /// No description provided for @restoreInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from today'**
  String get restoreInfoTitle;

  /// No description provided for @restoreInfoBody.
  ///
  /// In en, this message translates to:
  /// **'A new active schedule begins today. Archived dates never become missed days.'**
  String get restoreInfoBody;

  /// No description provided for @startAgainTitle.
  ///
  /// In en, this message translates to:
  /// **'Start again, gently'**
  String get startAgainTitle;

  /// No description provided for @startAgainBody.
  ///
  /// In en, this message translates to:
  /// **'You can begin with a tiny routine. No streak needs to be perfect.'**
  String get startAgainBody;

  /// No description provided for @startAgainLink.
  ///
  /// In en, this message translates to:
  /// **'Create a new habit'**
  String get startAgainLink;

  /// No description provided for @restoredMessage.
  ///
  /// In en, this message translates to:
  /// **'Restored. A new schedule begins today.'**
  String get restoredMessage;

  /// The app's one day-month date, day first (design: "29 May").
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String dayMonth(DateTime date);

  /// Screen reader label of 12's Edit button.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String detailEditLabel(String name);

  /// Day-first full date (design: "25 May 2026").
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String fullDate(DateTime date);

  /// Today's header (design 05: "Thursday, 28 May 2026").
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String weekdayDate(DateTime date);

  /// A day-month with the locale's time ("28 May, 10:15 AM").
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String dayMonthTime(DateTime date, DateTime time);

  /// No description provided for @progressOf.
  ///
  /// In en, this message translates to:
  /// **'{value} / {target} {unit}'**
  String progressOf(String value, String target, String unit);

  /// No description provided for @plusAmount.
  ///
  /// In en, this message translates to:
  /// **'+{amount}'**
  String plusAmount(String amount);

  /// No description provided for @minutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} s'**
  String minutesSeconds(int minutes, int seconds);

  /// No description provided for @minutesUnit.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesUnit;

  /// No description provided for @amountTitleProgress.
  ///
  /// In en, this message translates to:
  /// **'Add progress'**
  String get amountTitleProgress;

  /// No description provided for @amountTitleTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get amountTitleTime;

  /// No description provided for @amountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{habit} · {progress} saved today'**
  String amountSubtitle(String habit, String progress);

  /// No description provided for @amountCustomIn.
  ///
  /// In en, this message translates to:
  /// **'Custom amount in {unit}'**
  String amountCustomIn(String unit);

  /// No description provided for @amountCustomMinutes.
  ///
  /// In en, this message translates to:
  /// **'Custom time in minutes'**
  String get amountCustomMinutes;

  /// No description provided for @amountStepperLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount to add'**
  String get amountStepperLabel;

  /// No description provided for @amountLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get amountLess;

  /// No description provided for @amountMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get amountMore;

  /// No description provided for @amountAfterSaving.
  ///
  /// In en, this message translates to:
  /// **'After saving'**
  String get amountAfterSaving;

  /// No description provided for @amountNotComplete.
  ///
  /// In en, this message translates to:
  /// **'Not complete yet'**
  String get amountNotComplete;

  /// No description provided for @amountReached.
  ///
  /// In en, this message translates to:
  /// **'Today\'s target is reached'**
  String get amountReached;

  /// No description provided for @amountAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {amount}'**
  String amountAdd(String amount);

  /// No description provided for @amountCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel · keep saved value'**
  String get amountCancel;

  /// No description provided for @amountTimeIt.
  ///
  /// In en, this message translates to:
  /// **'Time it instead'**
  String get amountTimeIt;

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Add an amount.'**
  String get amountRequired;

  /// No description provided for @amountTooMuch.
  ///
  /// In en, this message translates to:
  /// **'Today can\'t hold that much.'**
  String get amountTooMuch;

  /// No description provided for @amountOneTap.
  ///
  /// In en, this message translates to:
  /// **'This habit is checked in with one tap on Today.'**
  String get amountOneTap;

  /// No description provided for @amountBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get amountBack;

  /// No description provided for @progressOfSpoken.
  ///
  /// In en, this message translates to:
  /// **'{value} of {target} {unit}'**
  String progressOfSpoken(String value, String target, String unit);

  /// No description provided for @todayProgressDone.
  ///
  /// In en, this message translates to:
  /// **'{progress} · done'**
  String todayProgressDone(String progress);

  /// No description provided for @todayTimerRunning.
  ///
  /// In en, this message translates to:
  /// **'Timer running · {time}'**
  String todayTimerRunning(String time);

  /// No description provided for @todayTimerPaused.
  ///
  /// In en, this message translates to:
  /// **'Timer paused · {time}'**
  String todayTimerPaused(String time);

  /// No description provided for @todayTimerRunningSpoken.
  ///
  /// In en, this message translates to:
  /// **'Timer running, {minutes, plural, =1{1 minute} other{{minutes} minutes}} so far'**
  String todayTimerRunningSpoken(int minutes);

  /// No description provided for @todayTimerPausedSpoken.
  ///
  /// In en, this message translates to:
  /// **'Timer paused at {minutes, plural, =1{1 minute} other{{minutes} minutes}}'**
  String todayTimerPausedSpoken(int minutes);

  /// No description provided for @todayOpenTimer.
  ///
  /// In en, this message translates to:
  /// **'Open timer'**
  String get todayOpenTimer;

  /// No description provided for @todayAmountSpoken.
  ///
  /// In en, this message translates to:
  /// **'{habit}: {progress}'**
  String todayAmountSpoken(String habit, String progress);

  /// No description provided for @todayAddSpoken.
  ///
  /// In en, this message translates to:
  /// **'Add {amount}'**
  String todayAddSpoken(String amount);

  /// No description provided for @detailStartTimer.
  ///
  /// In en, this message translates to:
  /// **'Start timer'**
  String get detailStartTimer;

  /// No description provided for @timerRunningTitle.
  ///
  /// In en, this message translates to:
  /// **'A moment to breathe'**
  String get timerRunningTitle;

  /// No description provided for @timerRunningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{habit} · {minutes}-minute daily target'**
  String timerRunningSubtitle(String habit, String minutes);

  /// No description provided for @timerPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pause at your pace'**
  String get timerPausedTitle;

  /// No description provided for @timerPausedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{habit} · your elapsed time is preserved'**
  String timerPausedSubtitle(String habit);

  /// No description provided for @timerOver.
  ///
  /// In en, this message translates to:
  /// **'{elapsed} / {target}'**
  String timerOver(String elapsed, String target);

  /// No description provided for @timerSpoken.
  ///
  /// In en, this message translates to:
  /// **'{elapsed, plural, =1{1 minute} other{{elapsed} minutes}} of {target} minutes'**
  String timerSpoken(int elapsed, String target);

  /// No description provided for @timerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get timerPause;

  /// No description provided for @timerResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get timerResume;

  /// No description provided for @timerTodayTotal.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute today} other{{minutes} minutes today}}'**
  String timerTodayTotal(int minutes);

  /// No description provided for @timerKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going if you like. You can save partial time without pretending the habit is complete.'**
  String get timerKeepGoing;

  /// No description provided for @timerPauseButton.
  ///
  /// In en, this message translates to:
  /// **'Pause timer'**
  String get timerPauseButton;

  /// No description provided for @timerResumeButton.
  ///
  /// In en, this message translates to:
  /// **'Resume timer'**
  String get timerResumeButton;

  /// No description provided for @timerFinish.
  ///
  /// In en, this message translates to:
  /// **'Save progress and finish'**
  String get timerFinish;

  /// No description provided for @timerRunningNote.
  ///
  /// In en, this message translates to:
  /// **'The timer continues locally without network access.'**
  String get timerRunningNote;

  /// No description provided for @timerPausedNote.
  ///
  /// In en, this message translates to:
  /// **'Returning to Today keeps partial progress.'**
  String get timerPausedNote;

  /// No description provided for @timerPausedCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Timer paused'**
  String get timerPausedCardTitle;

  /// No description provided for @timerPausedCardBody.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute is saved in the draft.} other{{minutes} minutes are saved in the draft.}} Nothing is logged until you finish and save.'**
  String timerPausedCardBody(int minutes);

  /// No description provided for @timerSavedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Saved {minutes} min.'**
  String timerSavedMinutes(int minutes);

  /// No description provided for @timerSavedSeconds.
  ///
  /// In en, this message translates to:
  /// **'Saved {seconds} s.'**
  String timerSavedSeconds(int seconds);

  /// No description provided for @timerNothingToSave.
  ///
  /// In en, this message translates to:
  /// **'Nothing to save yet.'**
  String get timerNothingToSave;

  /// No description provided for @timerGone.
  ///
  /// In en, this message translates to:
  /// **'This timer is no longer here.'**
  String get timerGone;

  /// No description provided for @timerTooLong.
  ///
  /// In en, this message translates to:
  /// **'This timer ran longer than a day can hold.'**
  String get timerTooLong;

  /// No description provided for @timerTooLongHint.
  ///
  /// In en, this message translates to:
  /// **'You can add time yourself from Today.'**
  String get timerTooLongHint;

  /// No description provided for @timerTooMuchToday.
  ///
  /// In en, this message translates to:
  /// **'Today can\'t hold that much time.'**
  String get timerTooMuchToday;

  /// No description provided for @timerArchived.
  ///
  /// In en, this message translates to:
  /// **'This habit is archived. Restore it to save this time.'**
  String get timerArchived;

  /// No description provided for @timerDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard timer'**
  String get timerDiscard;

  /// No description provided for @timerDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this timer?'**
  String get timerDiscardTitle;

  /// No description provided for @timerDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The time so far won\'t be saved.'**
  String get timerDiscardBody;

  /// No description provided for @timerDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get timerDiscardConfirm;

  /// No description provided for @timerKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep timer'**
  String get timerKeep;

  /// The reminder editor's next-due line, day first with a short weekday ("Thu 28 May, 10:15 AM").
  ///
  /// In en, this message translates to:
  /// **'{date}, {time}'**
  String weekdayDayMonthTime(DateTime date, DateTime time);

  /// No description provided for @entryDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get entryDone;

  /// No description provided for @entryNotDone.
  ///
  /// In en, this message translates to:
  /// **'Not done'**
  String get entryNotDone;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review one change'**
  String get reviewTitle;

  /// No description provided for @reviewStaleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Both devices edited the same {habit} entry on {date}.'**
  String reviewStaleSubtitle(String habit, String date);

  /// No description provided for @reviewSafeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your check-in is safe'**
  String get reviewSafeTitle;

  /// No description provided for @reviewSafeStaleBody.
  ///
  /// In en, this message translates to:
  /// **'This absolute edit needs your choice. Quantity increments normally merge automatically.'**
  String get reviewSafeStaleBody;

  /// No description provided for @reviewOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get reviewOnDevice;

  /// No description provided for @reviewLatestEntry.
  ///
  /// In en, this message translates to:
  /// **'Latest synced entry'**
  String get reviewLatestEntry;

  /// No description provided for @reviewLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest synced version'**
  String get reviewLatestVersion;

  /// No description provided for @reviewEditedAt.
  ///
  /// In en, this message translates to:
  /// **'Edited at {time} · based on version {version}'**
  String reviewEditedAt(String time, int version);

  /// No description provided for @reviewRemovedAt.
  ///
  /// In en, this message translates to:
  /// **'Removed at {time} · based on version {version}'**
  String reviewRemovedAt(String time, int version);

  /// No description provided for @reviewEditedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Edited on another device · version {version}'**
  String reviewEditedElsewhere(int version);

  /// No description provided for @reviewDeletedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Deleted on another device · version {version}'**
  String reviewDeletedElsewhere(int version);

  /// No description provided for @reviewArchivedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Archived on another device'**
  String get reviewArchivedElsewhere;

  /// No description provided for @reviewChangedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Changed on another device'**
  String get reviewChangedElsewhere;

  /// No description provided for @reviewFieldIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get reviewFieldIcon;

  /// No description provided for @reviewNote.
  ///
  /// In en, this message translates to:
  /// **'Your choice becomes a reviewed edit against the latest version. If it changes again, you will review it again.'**
  String get reviewNote;

  /// No description provided for @reviewNoteFields.
  ///
  /// In en, this message translates to:
  /// **'Fields that differ take the values you choose.'**
  String get reviewNoteFields;

  /// No description provided for @reviewKeepSynced.
  ///
  /// In en, this message translates to:
  /// **'Keep synced value · {value}'**
  String reviewKeepSynced(String value);

  /// No description provided for @reviewUseMine.
  ///
  /// In en, this message translates to:
  /// **'Use my value · {value}'**
  String reviewUseMine(String value);

  /// No description provided for @reviewEntryRemoved.
  ///
  /// In en, this message translates to:
  /// **'Entry removed'**
  String get reviewEntryRemoved;

  /// No description provided for @reviewRemoveEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove the entry'**
  String get reviewRemoveEntry;

  /// No description provided for @reviewDeletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This {habit} entry was deleted on another device.'**
  String reviewDeletedSubtitle(String habit);

  /// No description provided for @reviewDeletedBody.
  ///
  /// In en, this message translates to:
  /// **'The entry for this day was deleted on another device. Your change stays here until you choose.'**
  String get reviewDeletedBody;

  /// No description provided for @reviewDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get reviewDeleted;

  /// No description provided for @reviewKeepDeleted.
  ///
  /// In en, this message translates to:
  /// **'Keep it deleted'**
  String get reviewKeepDeleted;

  /// No description provided for @reviewBringBack.
  ///
  /// In en, this message translates to:
  /// **'Bring it back · {value}'**
  String reviewBringBack(String value);

  /// No description provided for @reviewBothRemoved.
  ///
  /// In en, this message translates to:
  /// **'Both devices removed this entry.'**
  String get reviewBothRemoved;

  /// No description provided for @reviewDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reviewDone;

  /// No description provided for @reviewArchivedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{habit} was archived on another device.'**
  String reviewArchivedSubtitle(String habit);

  /// No description provided for @reviewArchivedBody.
  ///
  /// In en, this message translates to:
  /// **'Restore {habit} to save this check-in, or discard it.'**
  String reviewArchivedBody(String habit);

  /// No description provided for @reviewArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get reviewArchived;

  /// No description provided for @reviewActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get reviewActive;

  /// No description provided for @reviewRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore {habit}'**
  String reviewRestore(String habit);

  /// No description provided for @reviewSaveCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Save my check-in · {value}'**
  String reviewSaveCheckIn(String value);

  /// No description provided for @reviewDiscardCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Discard this check-in'**
  String get reviewDiscardCheckIn;

  /// No description provided for @reviewHabitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Both devices edited {habit}.'**
  String reviewHabitSubtitle(String habit);

  /// No description provided for @reviewEditSafeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your edit is safe'**
  String get reviewEditSafeTitle;

  /// No description provided for @reviewEditSafeBody.
  ///
  /// In en, this message translates to:
  /// **'Your edit needs your choice before it is saved.'**
  String get reviewEditSafeBody;

  /// No description provided for @reviewKeepSyncedVersion.
  ///
  /// In en, this message translates to:
  /// **'Keep synced version'**
  String get reviewKeepSyncedVersion;

  /// No description provided for @reviewUseMyVersion.
  ///
  /// In en, this message translates to:
  /// **'Use my version'**
  String get reviewUseMyVersion;

  /// No description provided for @reviewUseMyChoice.
  ///
  /// In en, this message translates to:
  /// **'Use my choice'**
  String get reviewUseMyChoice;

  /// No description provided for @reviewArchiveThis.
  ///
  /// In en, this message translates to:
  /// **'Archive this habit'**
  String get reviewArchiveThis;

  /// No description provided for @reviewRestoreThis.
  ///
  /// In en, this message translates to:
  /// **'Restore this habit'**
  String get reviewRestoreThis;

  /// No description provided for @reviewFieldLine.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String reviewFieldLine(String label, String value);

  /// No description provided for @reviewFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reviewFieldName;

  /// No description provided for @reviewFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get reviewFieldCategory;

  /// No description provided for @reviewFieldTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get reviewFieldTarget;

  /// No description provided for @reviewFieldUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get reviewFieldUnit;

  /// No description provided for @reviewFieldSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get reviewFieldSchedule;

  /// No description provided for @reviewNoUnit.
  ///
  /// In en, this message translates to:
  /// **'No unit'**
  String get reviewNoUnit;

  /// No description provided for @reviewDiscardChange.
  ///
  /// In en, this message translates to:
  /// **'Discard this change'**
  String get reviewDiscardChange;

  /// No description provided for @reviewKeptSynced.
  ///
  /// In en, this message translates to:
  /// **'Kept the synced value.'**
  String get reviewKeptSynced;

  /// No description provided for @reviewUsedMine.
  ///
  /// In en, this message translates to:
  /// **'Your choice is saved on this device and will sync.'**
  String get reviewUsedMine;

  /// No description provided for @reviewGone.
  ///
  /// In en, this message translates to:
  /// **'This change no longer needs a look.'**
  String get reviewGone;

  /// No description provided for @reviewCardSpoken.
  ///
  /// In en, this message translates to:
  /// **'{title}: {value}. {line}'**
  String reviewCardSpoken(String title, String value, String line);

  /// No description provided for @queueReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get queueReview;

  /// No description provided for @queueChangeIncrement.
  ///
  /// In en, this message translates to:
  /// **'Progress added'**
  String get queueChangeIncrement;

  /// No description provided for @queueChangeHabitEdit.
  ///
  /// In en, this message translates to:
  /// **'Habit edited'**
  String get queueChangeHabitEdit;

  /// No description provided for @queueChangeArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get queueChangeArchived;

  /// No description provided for @queueChangeRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get queueChangeRestored;

  /// No description provided for @reasonHabitArchived.
  ///
  /// In en, this message translates to:
  /// **'This habit was archived on another device.'**
  String get reasonHabitArchived;

  /// A change with no base version (an increment, A35).
  ///
  /// In en, this message translates to:
  /// **'Edited at {time}'**
  String reviewEditedAtOnly(String time);

  /// No description provided for @reviewDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Discarded this change.'**
  String get reviewDiscarded;

  /// No description provided for @reviewAddedAt.
  ///
  /// In en, this message translates to:
  /// **'Added at {time}'**
  String reviewAddedAt(String time);

  /// No description provided for @reviewEditedAtFirst.
  ///
  /// In en, this message translates to:
  /// **'Edited at {time} · first entry of the day'**
  String reviewEditedAtFirst(String time);

  /// No description provided for @reviewRemovedAtFirst.
  ///
  /// In en, this message translates to:
  /// **'Removed at {time} · first entry of the day'**
  String reviewRemovedAtFirst(String time);

  /// Design 05: the confirmed reward numbers under the Today summary (A44).
  ///
  /// In en, this message translates to:
  /// **'{xp} XP · Level {level}'**
  String todayRewardLine(int xp, int level);

  /// Screen reader label for todayRewardLine.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP, Level {level}'**
  String todayRewardLineLabel(int xp, int level);

  /// Design 20: place, level and XP under the name.
  ///
  /// In en, this message translates to:
  /// **'{place} · Level {level} · {xp} XP'**
  String profileRewardLine(String place, int level, int xp);

  /// Design 20's line when the profile has no place.
  ///
  /// In en, this message translates to:
  /// **'Level {level} · {xp} XP'**
  String profileRewardLineNoPlace(int level, int xp);

  /// Queue (18): a queued profile.set_auto_freeze with enabled true.
  ///
  /// In en, this message translates to:
  /// **'Auto-protect turned on'**
  String get queueChangeAutoFreezeOn;

  /// Queue (18): a queued profile.set_auto_freeze with enabled false.
  ///
  /// In en, this message translates to:
  /// **'Auto-protect turned off'**
  String get queueChangeAutoFreezeOff;

  /// Screen 16 title.
  ///
  /// In en, this message translates to:
  /// **'Progress you earned'**
  String get progressTitle;

  /// Screen 16: the confirmed level, in capitals as designed.
  ///
  /// In en, this message translates to:
  /// **'LEVEL {level}'**
  String progressLevel(int level);

  /// Screen 16: the confirmed XP.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String progressXp(int xp);

  /// Screen 16: the level bar's label (A44).
  ///
  /// In en, this message translates to:
  /// **'{into} / {span} XP toward Level {level}'**
  String progressToward(int into, int span, int level);

  /// Screen 16 before any confirmed reward_state.
  ///
  /// In en, this message translates to:
  /// **'Your progress appears after the first sync.'**
  String get progressNoNumbers;

  /// No description provided for @progressRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent XP'**
  String get progressRecent;

  /// Screen 16's footer note, as designed.
  ///
  /// In en, this message translates to:
  /// **'10 XP per completed habit per day.\nRepeated increments never add extra XP.'**
  String get progressFooter;

  /// No description provided for @ledgerLoadError.
  ///
  /// In en, this message translates to:
  /// **'This could not be loaded right now.'**
  String get ledgerLoadError;

  /// No description provided for @ledgerTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get ledgerTryAgain;

  /// No description provided for @ledgerShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get ledgerShowMore;

  /// No description provided for @ledgerMoreError.
  ///
  /// In en, this message translates to:
  /// **'More could not be loaded. The list above is unchanged.'**
  String get ledgerMoreError;

  /// No description provided for @ledgerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get ledgerEmpty;

  /// No description provided for @ledgerToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get ledgerToday;

  /// No description provided for @ledgerYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get ledgerYesterday;

  /// A history row whose habit is not on this device.
  ///
  /// In en, this message translates to:
  /// **'A habit'**
  String get ledgerHabitUnknown;

  /// No description provided for @xpRowCompletedValue.
  ///
  /// In en, this message translates to:
  /// **'{day} · completed {value}'**
  String xpRowCompletedValue(String day, String value);

  /// No description provided for @xpRowCompleted.
  ///
  /// In en, this message translates to:
  /// **'{day} · completed'**
  String xpRowCompleted(String day);

  /// A reversal row (A40), neutral.
  ///
  /// In en, this message translates to:
  /// **'{day} · Check-in changed'**
  String xpRowChanged(String day);

  /// A ledger reason this app does not know (invariant 13).
  ///
  /// In en, this message translates to:
  /// **'{day} · XP update'**
  String xpRowUnknown(String day);

  /// No description provided for @xpAmountGained.
  ///
  /// In en, this message translates to:
  /// **'+{n} XP'**
  String xpAmountGained(int n);

  /// A negative ledger delta, with a minus sign (never colour alone).
  ///
  /// In en, this message translates to:
  /// **'−{n} XP'**
  String xpAmountReturned(int n);

  /// One merged screen-reader label for a history row.
  ///
  /// In en, this message translates to:
  /// **'{title}, {detail}, {amount}'**
  String ledgerRowLabel(String title, String detail, String amount);

  /// Screen 17 title.
  ///
  /// In en, this message translates to:
  /// **'A little breathing room'**
  String get freezesTitle;

  /// No description provided for @freezesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Protect continuity, not a pretend check-in.'**
  String get freezesSubtitle;

  /// No description provided for @freezesBalanceCap.
  ///
  /// In en, this message translates to:
  /// **'{balance} / {cap} freezes'**
  String freezesBalanceCap(int balance, int cap);

  /// Screen 17 before GET /freezes has answered.
  ///
  /// In en, this message translates to:
  /// **'{balance, plural, =1{1 freeze} other{{balance} freezes}}'**
  String freezesBalance(int balance);

  /// No description provided for @freezesNoNumbers.
  ///
  /// In en, this message translates to:
  /// **'Your freezes appear after the first sync.'**
  String get freezesNoNumbers;

  /// Screen 17: the server's next_refill_on (A43), never computed here.
  ///
  /// In en, this message translates to:
  /// **'Next refill: {date} · up to {cap} total'**
  String freezesRefill(String date, int cap);

  /// No description provided for @autoProtectTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-protect missed periods'**
  String get autoProtectTitle;

  /// No description provided for @autoProtectBody.
  ///
  /// In en, this message translates to:
  /// **'After a scheduled day or week closes'**
  String get autoProtectBody;

  /// ASSUMPTION(A11-prospective-line): opting in never protects earlier misses.
  ///
  /// In en, this message translates to:
  /// **'Turning it on protects periods that close from now on.'**
  String get autoProtectProspective;

  /// No description provided for @autoProtectQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. It applies after syncing.'**
  String get autoProtectQueued;

  /// No description provided for @autoProtectNeedsLook.
  ///
  /// In en, this message translates to:
  /// **'This change needs a look in the sync queue.'**
  String get autoProtectNeedsLook;

  /// No description provided for @freezesHistory.
  ///
  /// In en, this message translates to:
  /// **'Usage history'**
  String get freezesHistory;

  /// No description provided for @freezeRowTitle.
  ///
  /// In en, this message translates to:
  /// **'{habit} · {date}'**
  String freezeRowTitle(String habit, String date);

  /// No description provided for @freezeSpendDaily.
  ///
  /// In en, this message translates to:
  /// **'1 freeze used · daily period protected'**
  String get freezeSpendDaily;

  /// No description provided for @freezeSpendWeekly.
  ///
  /// In en, this message translates to:
  /// **'1 freeze used · weekly period protected'**
  String get freezeSpendWeekly;

  /// No description provided for @freezeSpendOther.
  ///
  /// In en, this message translates to:
  /// **'1 freeze used · period protected'**
  String get freezeSpendOther;

  /// ASSUMPTION(A41-refund-row-copy).
  ///
  /// In en, this message translates to:
  /// **'1 freeze returned · completed later'**
  String get freezeRefund;

  /// ASSUMPTION(A41-refund-row-copy): a zero refund at the cap.
  ///
  /// In en, this message translates to:
  /// **'Completed later · your wallet was already full'**
  String get freezeRefundAtCap;

  /// ASSUMPTION(A41-grant-row-copy).
  ///
  /// In en, this message translates to:
  /// **'Starting freezes'**
  String get freezeSignup;

  /// ASSUMPTION(A41-grant-row-copy).
  ///
  /// In en, this message translates to:
  /// **'Monthly refill'**
  String get freezeMonthly;

  /// ASSUMPTION(A41-grant-row-copy): a zero monthly grant at the cap.
  ///
  /// In en, this message translates to:
  /// **'Your wallet was already full'**
  String get freezeAlreadyFull;

  /// No description provided for @freezeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Freeze update'**
  String get freezeUnknown;

  /// No description provided for @freezeNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Protection is not completion'**
  String get freezeNoteTitle;

  /// No description provided for @freezeNoteBody.
  ///
  /// In en, this message translates to:
  /// **'No XP is awarded for a freeze. A real completion later can return the token once.'**
  String get freezeNoteBody;

  /// ASSUMPTION(A5-profile-rows): the Profile row that opens 16.
  ///
  /// In en, this message translates to:
  /// **'XP and levels'**
  String get profileRowProgress;

  /// No description provided for @profileRowProgressEmpty.
  ///
  /// In en, this message translates to:
  /// **'Appears after the first sync'**
  String get profileRowProgressEmpty;

  /// ASSUMPTION(A5-profile-rows): the Profile row that opens 17.
  ///
  /// In en, this message translates to:
  /// **'Freezes'**
  String get profileRowFreezes;

  /// No description provided for @profileRowFreezesOn.
  ///
  /// In en, this message translates to:
  /// **'{freezes} · auto-protect on'**
  String profileRowFreezesOn(String freezes);

  /// No description provided for @profileRowFreezesOff.
  ///
  /// In en, this message translates to:
  /// **'{freezes} · auto-protect off'**
  String profileRowFreezesOff(String freezes);

  /// Screen 17's refill date, full month (design: "1 June").
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String refillDate(DateTime date);

  /// Screen 17's refill date in another year.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String refillDateYear(DateTime date);

  /// Screens 06 and 35 title.
  ///
  /// In en, this message translates to:
  /// **'That counts.'**
  String get completeTitle;

  /// No description provided for @completeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A moment for yourself, a little progress.'**
  String get completeSubtitle;

  /// Screens 06 and 35 (design: "Meditation complete").
  ///
  /// In en, this message translates to:
  /// **'{habit} complete'**
  String completeHeading(String habit);

  /// ASSUMPTION(A5-complete-line): the day's logged value; the design's prose cannot be derived.
  ///
  /// In en, this message translates to:
  /// **'{value} logged today'**
  String completeLine(String value);

  /// The ack's xp_delta (A46), never a constant.
  ///
  /// In en, this message translates to:
  /// **'+{n} XP'**
  String completeXpChip(int n);

  /// Screen reader label for the XP chip.
  ///
  /// In en, this message translates to:
  /// **'{n} XP earned'**
  String completeXpChipLabel(int n);

  /// No description provided for @completeLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String completeLevel(int level);

  /// No description provided for @completeXpTotal.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP total'**
  String completeXpTotal(int xp);

  /// One screen-reader label for the Level card.
  ///
  /// In en, this message translates to:
  /// **'Level {level}, {xp} XP total, {into} of {span} XP toward Level {next}'**
  String completeLevelCardLabel(int level, int xp, int into, int span, int next);

  /// No description provided for @completeBack.
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get completeBack;

  /// No description provided for @completeFooter.
  ///
  /// In en, this message translates to:
  /// **'Missed days never erase what you have learned.'**
  String get completeFooter;

  /// A46: the save screen while it waits for the ack (at most 6 seconds).
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. Confirming…'**
  String get saveConfirming;

  /// No description provided for @insightsWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get insightsWeek;

  /// No description provided for @insightsMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get insightsMonth;

  /// Screen 14 title.
  ///
  /// In en, this message translates to:
  /// **'A week of progress'**
  String get insightsWeekTitle;

  /// Screen 14 (design: "25–31 May · this week is still in progress.").
  ///
  /// In en, this message translates to:
  /// **'{range} · this week is still in progress.'**
  String insightsWeekSubtitle(String range);

  /// A date range, en dash, no spaces.
  ///
  /// In en, this message translates to:
  /// **'{start}–{end}'**
  String insightsRange(String start, String end);

  /// No description provided for @insightsPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String insightsPercent(int percent);

  /// No description provided for @insightsClosedPeriods.
  ///
  /// In en, this message translates to:
  /// **'{completed} / {eligible} closed periods'**
  String insightsClosedPeriods(int completed, int eligible);

  /// No description provided for @insightsNoClosedPeriods.
  ///
  /// In en, this message translates to:
  /// **'No closed periods yet'**
  String get insightsNoClosedPeriods;

  /// No description provided for @insightsXp.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String insightsXp(int xp);

  /// No description provided for @insightsThrough.
  ///
  /// In en, this message translates to:
  /// **'Through {date}'**
  String insightsThrough(String date);

  /// No description provided for @insightsNoClosedDays.
  ///
  /// In en, this message translates to:
  /// **'No closed days yet'**
  String get insightsNoClosedDays;

  /// No description provided for @insightsCheckIns.
  ///
  /// In en, this message translates to:
  /// **'Completed check-ins'**
  String get insightsCheckIns;

  /// No description provided for @insightsTodayOpen.
  ///
  /// In en, this message translates to:
  /// **'Today is still open'**
  String get insightsTodayOpen;

  /// A day bar's screen-reader label.
  ///
  /// In en, this message translates to:
  /// **'{day}, {completed} of {due} completed'**
  String insightsDayLabel(String day, int completed, int due);

  /// No description provided for @insightsTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today so far, {completed} of {due} completed'**
  String insightsTodayLabel(int completed, int due);

  /// No description provided for @insightsFutureLabel.
  ///
  /// In en, this message translates to:
  /// **'{day}, not yet'**
  String insightsFutureLabel(String day);

  /// No description provided for @insightsOpenWeekly.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {target} distinct days this week'**
  String insightsOpenWeekly(int completed, int target);

  /// No description provided for @insightsPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get insightsPending;

  /// No description provided for @insightsWeekNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Consistency without pressure'**
  String get insightsWeekNoteTitle;

  /// No description provided for @insightsWeekNoteBody.
  ///
  /// In en, this message translates to:
  /// **'Only closed, eligible periods count. Future days and archived routines are excluded.'**
  String get insightsWeekNoteBody;

  /// Screen 15 title.
  ///
  /// In en, this message translates to:
  /// **'Your consistency'**
  String get insightsMonthTitle;

  /// No description provided for @insightsMonthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{month} · closed periods through {date}.'**
  String insightsMonthSubtitle(String month, String date);

  /// No description provided for @insightsMonthSubtitleNone.
  ///
  /// In en, this message translates to:
  /// **'{month} · no closed periods yet.'**
  String insightsMonthSubtitleNone(String month);

  /// No description provided for @insightsEligiblePeriods.
  ///
  /// In en, this message translates to:
  /// **'{completed} / {eligible} eligible periods'**
  String insightsEligiblePeriods(int completed, int eligible);

  /// No description provided for @insightsByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get insightsByCategory;

  /// No description provided for @insightsCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'{category}, {completed} of {eligible}, {percent} percent'**
  String insightsCategoryLabel(String category, int completed, int eligible, int percent);

  /// A56: the Insights summary card's title, Week.
  ///
  /// In en, this message translates to:
  /// **'XP this week'**
  String get insightsSummaryWeek;

  /// A56: the Insights summary card's title, Month.
  ///
  /// In en, this message translates to:
  /// **'XP this month'**
  String get insightsSummaryMonth;

  /// A56: caption under the percentage on the Insights summary card.
  ///
  /// In en, this message translates to:
  /// **'Consistency'**
  String get insightsConsistency;

  /// A56: opens the system share sheet with an image of the summary card; nothing is posted by the app.
  ///
  /// In en, this message translates to:
  /// **'Share progress'**
  String get insightsShare;

  /// A56: toast when the share image fails.
  ///
  /// In en, this message translates to:
  /// **'The image could not be prepared. Try again.'**
  String get insightsShareFailed;

  /// No description provided for @insightsMonthFooter.
  ///
  /// In en, this message translates to:
  /// **'Protected periods keep a streak, but do not count as completed habits.'**
  String get insightsMonthFooter;

  /// No description provided for @insightsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Insights could not be loaded right now.'**
  String get insightsLoadError;

  /// No description provided for @insightsOfflineNone.
  ///
  /// In en, this message translates to:
  /// **'Insights need a connection. They appear once your phone is back online.'**
  String get insightsOfflineNone;

  /// No description provided for @insightsOfflineLast.
  ///
  /// In en, this message translates to:
  /// **'These are the last numbers from this session.'**
  String get insightsOfflineLast;

  /// No description provided for @insightsUnsynced.
  ///
  /// In en, this message translates to:
  /// **'Check-ins waiting to sync aren\'t counted yet.'**
  String get insightsUnsynced;

  /// Insights: a refresh failed while numbers are shown (5.3b review L2).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh right now.'**
  String get insightsRefreshFailed;

  /// No description provided for @profilePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy and export'**
  String get profilePrivacy;

  /// No description provided for @profilePrivacyLine.
  ///
  /// In en, this message translates to:
  /// **'Your history, portable and private'**
  String get profilePrivacyLine;

  /// Screen 21 title.
  ///
  /// In en, this message translates to:
  /// **'Your data, yours'**
  String get privacyTitle;

  /// No description provided for @privacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export habit history whenever you need it.'**
  String get privacySubtitle;

  /// No description provided for @privacyJson.
  ///
  /// In en, this message translates to:
  /// **'JSON backup'**
  String get privacyJson;

  /// No description provided for @privacyCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV history'**
  String get privacyCsv;

  /// No description provided for @privacyIncludedTitle.
  ///
  /// In en, this message translates to:
  /// **'Included in your export'**
  String get privacyIncludedTitle;

  /// No description provided for @privacyIncludedBody.
  ///
  /// In en, this message translates to:
  /// **'Habits, logs, rewards, freeze history'**
  String get privacyIncludedBody;

  /// No description provided for @privacyIncludedAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get privacyIncludedAll;

  /// No description provided for @privacyUpToDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud history is up to date'**
  String get privacyUpToDateTitle;

  /// No description provided for @privacyUpToDateBody.
  ///
  /// In en, this message translates to:
  /// **'Last synced {when}. Pending changes must sync before a full server export.'**
  String privacyUpToDateBody(String when);

  /// No description provided for @privacyNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet. Pending changes must sync before a full server export.'**
  String get privacyNeverSynced;

  /// No description provided for @privacyPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to sync} other{{count} changes waiting to sync}}'**
  String privacyPendingTitle(int count);

  /// No description provided for @privacyPendingBody.
  ///
  /// In en, this message translates to:
  /// **'They reach a server export only after syncing.'**
  String get privacyPendingBody;

  /// No description provided for @privacyLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest export · {status}'**
  String privacyLatest(String status);

  /// No description provided for @privacyLatestNone.
  ///
  /// In en, this message translates to:
  /// **'No export yet'**
  String get privacyLatestNone;

  /// No description provided for @privacyRequested.
  ///
  /// In en, this message translates to:
  /// **'{format} · requested {date}'**
  String privacyRequested(String format, String date);

  /// No description provided for @privacyExpiresNote.
  ///
  /// In en, this message translates to:
  /// **'Private download expires after 24 hours.'**
  String get privacyExpiresNote;

  /// No description provided for @privacyDownload.
  ///
  /// In en, this message translates to:
  /// **'Download latest export'**
  String get privacyDownload;

  /// No description provided for @privacyRequest.
  ///
  /// In en, this message translates to:
  /// **'Request new export'**
  String get privacyRequest;

  /// No description provided for @privacyFooter.
  ///
  /// In en, this message translates to:
  /// **'Exports are private. Download links are temporary.'**
  String get privacyFooter;

  /// No description provided for @privacyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Your exports could not be loaded right now.'**
  String get privacyLoadError;

  /// No description provided for @privacyDownloadError.
  ///
  /// In en, this message translates to:
  /// **'The download did not finish. Try again when you\'re online.'**
  String get privacyDownloadError;

  /// 6.1 review L4: the download answered 410 export_expired; the export list is reloaded.
  ///
  /// In en, this message translates to:
  /// **'This download has expired. Request a new export.'**
  String get privacyDownloadExpired;

  /// Screen 21: opens screen 28 (A49).
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get privacyDeleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes your saved routines and history.'**
  String get deleteAccountSubtitle;

  /// No description provided for @deleteAccountExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export before you leave'**
  String get deleteAccountExportTitle;

  /// No description provided for @deleteAccountExportBody.
  ///
  /// In en, this message translates to:
  /// **'Download your history first if you want to keep it. Pending changes need to sync.'**
  String get deleteAccountExportBody;

  /// Screen 28: added to the export card while the outbox holds unacknowledged rows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change is still waiting to sync.} other{{count} changes are still waiting to sync.}}'**
  String deleteAccountPending(int count);

  /// No description provided for @deleteAccountPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get deleteAccountPasswordLabel;

  /// No description provided for @deleteAccountNextTitle.
  ///
  /// In en, this message translates to:
  /// **'What happens next'**
  String get deleteAccountNextTitle;

  /// No description provided for @deleteAccountNextBody.
  ///
  /// In en, this message translates to:
  /// **'Sessions are revoked immediately. Owned data is queued for deletion under the retention policy.'**
  String get deleteAccountNextBody;

  /// No description provided for @deleteAccountKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get deleteAccountKeep;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete account permanently'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountOffline.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account needs a connection.'**
  String get deleteAccountOffline;

  /// No description provided for @deleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'Your account could not be deleted right now. Nothing has changed.'**
  String get deleteAccountError;

  /// No description provided for @deleteAccountTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get deleteAccountTryAgain;

  /// No description provided for @signInForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get signInForgotPassword;

  /// No description provided for @signInPasswordChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your password has changed.'**
  String get signInPasswordChangedTitle;

  /// Screen 02 after a reset (A50): one calm line, title plus body.
  ///
  /// In en, this message translates to:
  /// **'Sign in with the new one.'**
  String get signInPasswordChangedBody;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'A fresh start'**
  String get forgotTitle;

  /// Screen 25. The design says 'reset link'; A50 sends a code.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to get a reset code.'**
  String get forgotSubtitle;

  /// No description provided for @forgotPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Private and secure'**
  String get forgotPrivateTitle;

  /// No description provided for @forgotPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'The response is the same whether or not an account uses this email.'**
  String get forgotPrivateBody;

  /// No description provided for @forgotSend.
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get forgotSend;

  /// No description provided for @forgotBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get forgotBackToSignIn;

  /// No description provided for @resetSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get resetSentTitle;

  /// No description provided for @resetSentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If an account matches, a reset email is on its way.'**
  String get resetSentSubtitle;

  /// No description provided for @resetSentBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from the email to choose a new password.'**
  String get resetSentBody;

  /// No description provided for @resetSentNothingTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing arrived?'**
  String get resetSentNothingTitle;

  /// No description provided for @resetSentNothingBody.
  ///
  /// In en, this message translates to:
  /// **'Check your spam folder. You can request another code after the resend cooldown.'**
  String get resetSentNothingBody;

  /// No description provided for @resetSentEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get resetSentEnterCode;

  /// No description provided for @resetSentResend.
  ///
  /// In en, this message translates to:
  /// **'Resend reset email'**
  String get resetSentResend;

  /// No description provided for @resetSentResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend reset email in {seconds} s'**
  String resetSentResendIn(int seconds);

  /// TalkBack label for the disabled resend button during the 60-second cooldown.
  ///
  /// In en, this message translates to:
  /// **'Resend reset email, available in {seconds} seconds'**
  String resetSentResendInLabel(int seconds);

  /// No description provided for @resetSentResent.
  ///
  /// In en, this message translates to:
  /// **'We asked for a new code. It replaces the earlier one.'**
  String get resetSentResent;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get resetTitle;

  /// No description provided for @resetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A reset code can only be used once.'**
  String get resetSubtitle;

  /// No description provided for @resetCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get resetCodeLabel;

  /// No description provided for @resetCodeHint.
  ///
  /// In en, this message translates to:
  /// **'6 digits'**
  String get resetCodeHint;

  /// No description provided for @resetCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from the email.'**
  String get resetCodeInvalid;

  /// No description provided for @resetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetNewPassword;

  /// No description provided for @resetConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get resetConfirmPassword;

  /// No description provided for @resetMismatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords must match.'**
  String get resetMismatch;

  /// No description provided for @resetRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Use at least 12 characters'**
  String get resetRulesTitle;

  /// No description provided for @resetRulesBody.
  ///
  /// In en, this message translates to:
  /// **'The two passwords must match. Expired codes return to the reset request.'**
  String get resetRulesBody;

  /// No description provided for @resetSave.
  ///
  /// In en, this message translates to:
  /// **'Save new password'**
  String get resetSave;

  /// No description provided for @resetFooter.
  ///
  /// In en, this message translates to:
  /// **'Successful reset returns to sign in.'**
  String get resetFooter;

  /// No description provided for @resetRequestNewCode.
  ///
  /// In en, this message translates to:
  /// **'Request a new code'**
  String get resetRequestNewCode;

  /// No description provided for @signInAccountDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is being deleted.'**
  String get signInAccountDeletedTitle;

  /// Screen 02 after a deletion (A49): one calm line, title plus body.
  ///
  /// In en, this message translates to:
  /// **'Sessions on your other devices have ended.'**
  String get signInAccountDeletedBody;

  /// No description provided for @privacyRequestError.
  ///
  /// In en, this message translates to:
  /// **'The export could not be requested right now. Try again.'**
  String get privacyRequestError;

  /// No description provided for @exportStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'queued'**
  String get exportStatusQueued;

  /// No description provided for @exportStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'preparing'**
  String get exportStatusRunning;

  /// No description provided for @exportStatusReady.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get exportStatusReady;

  /// No description provided for @exportStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get exportStatusFailed;

  /// No description provided for @exportStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get exportStatusExpired;

  /// No description provided for @exportStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'updating'**
  String get exportStatusUnknown;

  /// No description provided for @exportFormatJson.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get exportFormatJson;

  /// No description provided for @exportFormatCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get exportFormatCsv;

  /// No description provided for @exportKindJson.
  ///
  /// In en, this message translates to:
  /// **'JSON backup'**
  String get exportKindJson;

  /// No description provided for @exportKindCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV history'**
  String get exportKindCsv;

  /// Screen 29 title.
  ///
  /// In en, this message translates to:
  /// **'Preparing your export'**
  String get exportPreparingTitle;

  /// No description provided for @exportPreparingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your history will be ready as a private download.'**
  String get exportPreparingSubtitle;

  /// No description provided for @exportQueuedTitle.
  ///
  /// In en, this message translates to:
  /// **'Queued securely'**
  String get exportQueuedTitle;

  /// No description provided for @exportQueuedBody.
  ///
  /// In en, this message translates to:
  /// **'{kind} requested {when}. This may take a little time.'**
  String exportQueuedBody(String kind, String when);

  /// No description provided for @exportReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to download'**
  String get exportReadyTitle;

  /// No description provided for @exportReadyBody.
  ///
  /// In en, this message translates to:
  /// **'{kind} requested {when}. Private download expires after 24 hours.'**
  String exportReadyBody(String kind, String when);

  /// No description provided for @exportIncludesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your export includes'**
  String get exportIncludesTitle;

  /// No description provided for @exportIncludesBody.
  ///
  /// In en, this message translates to:
  /// **'Habits and definitions\nCheck-in history\nReward and freeze records'**
  String get exportIncludesBody;

  /// No description provided for @exportLeaveNote.
  ///
  /// In en, this message translates to:
  /// **'You can leave this screen. The export status stays available in Privacy and export.'**
  String get exportLeaveNote;

  /// No description provided for @exportBackToPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Back to privacy and export'**
  String get exportBackToPrivacy;

  /// No description provided for @exportReadyFooter.
  ///
  /// In en, this message translates to:
  /// **'Download is available only after status is Ready.'**
  String get exportReadyFooter;

  /// Screen 30 title (design: Let’s try that again).
  ///
  /// In en, this message translates to:
  /// **'Let\'s try that again'**
  String get exportFailedTitle;

  /// No description provided for @exportFailedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your habits and history are unchanged.'**
  String get exportFailedSubtitle;

  /// No description provided for @exportFailedCardTitle.
  ///
  /// In en, this message translates to:
  /// **'The export did not finish'**
  String get exportFailedCardTitle;

  /// No description provided for @exportFailedCardBody.
  ///
  /// In en, this message translates to:
  /// **'No data was lost. Retry the job when a connection is available.'**
  String get exportFailedCardBody;

  /// No description provided for @exportFailedJob.
  ///
  /// In en, this message translates to:
  /// **'{kind} · failed'**
  String exportFailedJob(String kind);

  /// No description provided for @exportRequestFrom.
  ///
  /// In en, this message translates to:
  /// **'Request from {when}'**
  String exportRequestFrom(String when);

  /// No description provided for @exportRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry export'**
  String get exportRetry;

  /// No description provided for @exportWhenToday.
  ///
  /// In en, this message translates to:
  /// **'today at {time}'**
  String exportWhenToday(String time);

  /// No description provided for @exportWhenDay.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String exportWhenDay(String date, String time);
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
