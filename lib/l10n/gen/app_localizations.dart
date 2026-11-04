import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_km.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('km'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'e-Radio'**
  String get appTitle;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navExplore;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorite;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search radio, podcasts, songs...'**
  String get searchHint;

  /// No description provided for @liveStations.
  ///
  /// In en, this message translates to:
  /// **'Live Radio Stations'**
  String get liveStations;

  /// No description provided for @onAir.
  ///
  /// In en, this message translates to:
  /// **'On Air'**
  String get onAir;

  /// No description provided for @onAirNow.
  ///
  /// In en, this message translates to:
  /// **'On Air Now'**
  String get onAirNow;

  /// No description provided for @allStations.
  ///
  /// In en, this message translates to:
  /// **'All Stations'**
  String get allStations;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @listenRadio.
  ///
  /// In en, this message translates to:
  /// **'Listen Radio'**
  String get listenRadio;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @catPodcast.
  ///
  /// In en, this message translates to:
  /// **'Podcast'**
  String get catPodcast;

  /// No description provided for @catNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get catNews;

  /// No description provided for @catHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get catHealth;

  /// No description provided for @catEconomy.
  ///
  /// In en, this message translates to:
  /// **'Economy/Finance'**
  String get catEconomy;

  /// No description provided for @catSong.
  ///
  /// In en, this message translates to:
  /// **'Song'**
  String get catSong;

  /// No description provided for @newReleaseFrom.
  ///
  /// In en, this message translates to:
  /// **'New release from'**
  String get newReleaseFrom;

  /// No description provided for @notificationsImportant.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get notificationsImportant;

  /// No description provided for @notificationsMore.
  ///
  /// In en, this message translates to:
  /// **'More notifications'**
  String get notificationsMore;

  /// No description provided for @markAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllAsRead;

  /// No description provided for @hideNotification.
  ///
  /// In en, this message translates to:
  /// **'Hide this notification'**
  String get hideNotification;

  /// No description provided for @showFewerFrom.
  ///
  /// In en, this message translates to:
  /// **'Show fewer from {name}'**
  String showFewerFrom(String name);

  /// No description provided for @turnOffAllFrom.
  ///
  /// In en, this message translates to:
  /// **'Turn off all from {name}'**
  String turnOffAllFrom(String name);

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String hoursAgo(int count);

  /// No description provided for @catAmbient.
  ///
  /// In en, this message translates to:
  /// **'Ambient Music'**
  String get catAmbient;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get repeatOff;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get repeatAll;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat this song'**
  String get repeatOne;

  /// No description provided for @equalizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// No description provided for @equalizerReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get equalizerReset;

  /// No description provided for @equalizerPlayFirst.
  ///
  /// In en, this message translates to:
  /// **'Play a song to adjust the equalizer.'**
  String get equalizerPlayFirst;

  /// No description provided for @equalizerFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get equalizerFlat;

  /// No description provided for @equalizerBassBoost.
  ///
  /// In en, this message translates to:
  /// **'Bass boost'**
  String get equalizerBassBoost;

  /// No description provided for @equalizerTrebleBoost.
  ///
  /// In en, this message translates to:
  /// **'Treble boost'**
  String get equalizerTrebleBoost;

  /// No description provided for @equalizerVocal.
  ///
  /// In en, this message translates to:
  /// **'Vocal'**
  String get equalizerVocal;

  /// No description provided for @equalizerRock.
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get equalizerRock;

  /// No description provided for @equalizerPop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get equalizerPop;

  /// No description provided for @equalizerCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get equalizerCustom;

  /// No description provided for @streamUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Stream unavailable'**
  String get streamUnavailable;

  /// No description provided for @openInFacebook.
  ///
  /// In en, this message translates to:
  /// **'Open in Facebook'**
  String get openInFacebook;

  /// No description provided for @videoCantPlayHere.
  ///
  /// In en, this message translates to:
  /// **'This video can\'t be played in the app'**
  String get videoCantPlayHere;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @nextProgram.
  ///
  /// In en, this message translates to:
  /// **'Next Program'**
  String get nextProgram;

  /// No description provided for @todaysPrograms.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Programs'**
  String get todaysPrograms;

  /// No description provided for @replay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replay;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @noProgramsToday.
  ///
  /// In en, this message translates to:
  /// **'No programs scheduled today'**
  String get noProgramsToday;

  /// No description provided for @scheduleLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load today\'s programs'**
  String get scheduleLoadFailed;

  /// No description provided for @minimizePlayer.
  ///
  /// In en, this message translates to:
  /// **'Minimize player'**
  String get minimizePlayer;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently Played'**
  String get recentlyPlayed;

  /// No description provided for @noRecentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Nothing played yet'**
  String get noRecentlyPlayed;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavorites;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signUp;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in with Google. Please try again.'**
  String get googleSignInFailed;

  /// No description provided for @googleSignInCancelled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in didn\'t finish. Please try again.'**
  String get googleSignInCancelled;

  /// No description provided for @googleSignInRefused.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in didn\'t finish. Google said: {reason}'**
  String googleSignInRefused(String reason);

  /// No description provided for @googleSignInClosedEarly.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in closed straight away. Make sure a Google account is added to this device, then try again.'**
  String get googleSignInClosedEarly;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccount;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @khmer.
  ///
  /// In en, this message translates to:
  /// **'Khmer'**
  String get khmer;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @accountInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Info'**
  String get accountInfo;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @preloaderWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get preloaderWelcome;

  /// No description provided for @preloaderGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String preloaderGreetingMorning(String name);

  /// No description provided for @preloaderGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String preloaderGreetingAfternoon(String name);

  /// No description provided for @preloaderGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String preloaderGreetingEvening(String name);

  /// No description provided for @guestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save favorites and sync your profile'**
  String get guestSubtitle;

  /// No description provided for @station.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get station;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @emptySearch.
  ///
  /// In en, this message translates to:
  /// **'No stations match your search'**
  String get emptySearch;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// No description provided for @joinDate.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joinDate;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidCredentials;

  /// No description provided for @accountExists.
  ///
  /// In en, this message translates to:
  /// **'An account already exists on this device. Please sign in instead.'**
  String get accountExists;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @noStationsPublished.
  ///
  /// In en, this message translates to:
  /// **'No stations published yet'**
  String get noStationsPublished;

  /// No description provided for @noContentYet.
  ///
  /// In en, this message translates to:
  /// **'No content in this category yet'**
  String get noContentYet;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @accountInfoSaved.
  ///
  /// In en, this message translates to:
  /// **'Account info updated'**
  String get accountInfoSaved;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New items, updates, and profile reminders'**
  String get notificationsSubtitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @jumpBackIn.
  ///
  /// In en, this message translates to:
  /// **'Jump Back In'**
  String get jumpBackIn;

  /// No description provided for @trendingProgram.
  ///
  /// In en, this message translates to:
  /// **'Trending Programs'**
  String get trendingProgram;

  /// No description provided for @newRelease.
  ///
  /// In en, this message translates to:
  /// **'New Releases'**
  String get newRelease;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @writeAComment.
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get writeAComment;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Be the first!'**
  String get noCommentsYet;

  /// No description provided for @signInToComment.
  ///
  /// In en, this message translates to:
  /// **'Sign in to join the conversation'**
  String get signInToComment;

  /// No description provided for @deleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get deleteComment;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// No description provided for @addBookmark.
  ///
  /// In en, this message translates to:
  /// **'Add to bookmarks'**
  String get addBookmark;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove from bookmarks'**
  String get removeBookmark;

  /// No description provided for @remindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remindMe;

  /// No description provided for @reminderSetFor.
  ///
  /// In en, this message translates to:
  /// **'Reminder set for {time}'**
  String reminderSetFor(String time);

  /// No description provided for @cancelReminder.
  ///
  /// In en, this message translates to:
  /// **'Cancel reminder'**
  String get cancelReminder;

  /// No description provided for @reminderCreated.
  ///
  /// In en, this message translates to:
  /// **'Reminder set'**
  String get reminderCreated;

  /// No description provided for @reminderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Reminder cancelled'**
  String get reminderCancelled;

  /// No description provided for @notificationsPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications in system settings to get reminders'**
  String get notificationsPermissionNeeded;

  /// No description provided for @chooseReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Choose a reminder time'**
  String get chooseReminderTime;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingDiscoverHeadline.
  ///
  /// In en, this message translates to:
  /// **'Discover Live Radio'**
  String get onboardingDiscoverHeadline;

  /// No description provided for @onboardingDiscoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Listen to thousands of live stations anytime, anywhere.'**
  String get onboardingDiscoverSubtitle;

  /// No description provided for @onboardingPickFavoritesHeadline.
  ///
  /// In en, this message translates to:
  /// **'Pick Your Favorites'**
  String get onboardingPickFavoritesHeadline;

  /// No description provided for @onboardingPickFavoritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your favorite genres and stations to get a personalized experience.'**
  String get onboardingPickFavoritesSubtitle;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @onboardingOneTapHeadline.
  ///
  /// In en, this message translates to:
  /// **'One Tap to Play'**
  String get onboardingOneTapHeadline;

  /// No description provided for @onboardingOneTapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find, Save, and jump back into your favorite stations instantly.'**
  String get onboardingOneTapSubtitle;

  /// No description provided for @letsGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Go!'**
  String get letsGo;

  /// No description provided for @interestNewsTalk.
  ///
  /// In en, this message translates to:
  /// **'News & Talk'**
  String get interestNewsTalk;

  /// No description provided for @interestEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get interestEducation;

  /// No description provided for @interestSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get interestSports;

  /// No description provided for @interestMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get interestMusic;

  /// No description provided for @interestEconomy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get interestEconomy;

  /// No description provided for @interestInfotainment.
  ///
  /// In en, this message translates to:
  /// **'Infotainment'**
  String get interestInfotainment;

  /// No description provided for @interestLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get interestLifestyle;

  /// No description provided for @interestRadio.
  ///
  /// In en, this message translates to:
  /// **'Radio'**
  String get interestRadio;

  /// No description provided for @interestAmsPrograms.
  ///
  /// In en, this message translates to:
  /// **'AMS Programs'**
  String get interestAmsPrograms;

  /// No description provided for @interestCulture.
  ///
  /// In en, this message translates to:
  /// **'Culture'**
  String get interestCulture;

  /// No description provided for @interestRelaxation.
  ///
  /// In en, this message translates to:
  /// **'Relaxation'**
  String get interestRelaxation;

  /// No description provided for @interestAmbient.
  ///
  /// In en, this message translates to:
  /// **'Ambient'**
  String get interestAmbient;

  /// No description provided for @interestTrends.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get interestTrends;

  /// No description provided for @interestBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get interestBusiness;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to continue'**
  String get authSubtitle;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @firstNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your first name'**
  String get firstNameHint;

  /// No description provided for @lastNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your last name'**
  String get lastNameHint;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @haveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Have an account?'**
  String get haveAnAccount;

  /// No description provided for @signInLink.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInLink;

  /// No description provided for @signUpLink.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUpLink;

  /// No description provided for @termsPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our '**
  String get termsPrefix;

  /// No description provided for @termsLink.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get termsLink;

  /// No description provided for @termsAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get termsAnd;

  /// No description provided for @privacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyLink;

  /// No description provided for @termsSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get termsSuffix;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get emailInvalid;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsDontMatch;

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

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get orDivider;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @yourProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get yourProfile;

  /// No description provided for @percentComplete.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String percentComplete(int percent);

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @incomplete.
  ///
  /// In en, this message translates to:
  /// **'Incomplete'**
  String get incomplete;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @helpAndFeedback.
  ///
  /// In en, this message translates to:
  /// **'Help & feedback'**
  String get helpAndFeedback;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @changeProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Profile Photo'**
  String get changeProfilePhoto;

  /// No description provided for @photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated'**
  String get photoUpdated;

  /// No description provided for @photoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the photo. Please try again.'**
  String get photoUploadFailed;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @requirementsChecklist.
  ///
  /// In en, this message translates to:
  /// **'Requirements Checklist'**
  String get requirementsChecklist;

  /// No description provided for @reqLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters long'**
  String get reqLength;

  /// No description provided for @reqNumberOrSymbol.
  ///
  /// In en, this message translates to:
  /// **'Contains at least one number or symbol'**
  String get reqNumberOrSymbol;

  /// No description provided for @reqUpperLower.
  ///
  /// In en, this message translates to:
  /// **'Contains upper and lowercase letters'**
  String get reqUpperLower;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePassword;

  /// No description provided for @forgotCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot current password?'**
  String get forgotCurrentPassword;

  /// No description provided for @passwordRequirementsNotMet.
  ///
  /// In en, this message translates to:
  /// **'Your new password doesn\'t meet all the requirements'**
  String get passwordRequirementsNotMet;

  /// No description provided for @allowNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get allowNotifications;

  /// No description provided for @notificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Turn on to get the latest updates'**
  String get notificationsHint;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordHeading.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordHeading;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we will send you a code to reset your password.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @emailHintLong.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address...'**
  String get emailHintLong;

  /// No description provided for @sendResetCode.
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get sendResetCode;

  /// No description provided for @backTo.
  ///
  /// In en, this message translates to:
  /// **'Back to'**
  String get backTo;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get enterCode;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'A 6-digit code was sent to'**
  String get codeSentTo;

  /// No description provided for @codeExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Code expires in {time}'**
  String codeExpiresIn(String time);

  /// No description provided for @codeExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired'**
  String get codeExpired;

  /// No description provided for @didntGetCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get a code?'**
  String get didntGetCode;

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get resend;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code is incorrect or has expired'**
  String get invalidCode;

  /// No description provided for @codeResent.
  ///
  /// In en, this message translates to:
  /// **'A new code is on its way'**
  String get codeResent;

  /// No description provided for @pleaseWaitAndRetry.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get pleaseWaitAndRetry;

  /// No description provided for @couldntReachServer.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check your connection and try again.'**
  String get couldntReachServer;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @createNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Create New Password'**
  String get createNewPassword;

  /// No description provided for @createNewPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new password for your account'**
  String get createNewPasswordSubtitle;

  /// No description provided for @ruleLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get ruleLength;

  /// No description provided for @ruleUppercase.
  ///
  /// In en, this message translates to:
  /// **'At least one uppercase letter'**
  String get ruleUppercase;

  /// No description provided for @ruleNumber.
  ///
  /// In en, this message translates to:
  /// **'At least one number'**
  String get ruleNumber;

  /// No description provided for @ruleSpecial.
  ///
  /// In en, this message translates to:
  /// **'At least one special character'**
  String get ruleSpecial;

  /// No description provided for @passwordResetDone.
  ///
  /// In en, this message translates to:
  /// **'Your password was reset. Sign in with your new password.'**
  String get passwordResetDone;

  /// No description provided for @resetExpired.
  ///
  /// In en, this message translates to:
  /// **'This reset has expired. Please start again.'**
  String get resetExpired;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @podcasts.
  ///
  /// In en, this message translates to:
  /// **'Podcasts'**
  String get podcasts;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @allEpisodes.
  ///
  /// In en, this message translates to:
  /// **'All Episodes'**
  String get allEpisodes;

  /// No description provided for @playLatest.
  ///
  /// In en, this message translates to:
  /// **'Play Latest'**
  String get playLatest;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @byHost.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String byHost(String name);

  /// No description provided for @noPodcastsYet.
  ///
  /// In en, this message translates to:
  /// **'No podcasts yet'**
  String get noPodcastsYet;

  /// No description provided for @episodeCountBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} EP'**
  String episodeCountBadge(int count);

  /// No description provided for @noEpisodesYet.
  ///
  /// In en, this message translates to:
  /// **'No episodes yet'**
  String get noEpisodesYet;

  /// No description provided for @episodeDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get episodeDetails;

  /// No description provided for @episodesButton.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get episodesButton;

  /// No description provided for @episodeSection.
  ///
  /// In en, this message translates to:
  /// **'Episode'**
  String get episodeSection;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'see more'**
  String get seeMore;

  /// No description provided for @episodeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min} other{{count} mins}}'**
  String episodeMinutes(int count);

  /// No description provided for @viewCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 view} other{{count} views}}'**
  String viewCount(int count);

  /// No description provided for @episodeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get episodeToday;

  /// No description provided for @episodeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String episodeDaysAgo(int count);

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @tabLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get tabLocal;

  /// No description provided for @tabInternational.
  ///
  /// In en, this message translates to:
  /// **'International'**
  String get tabInternational;

  /// No description provided for @popularArtists.
  ///
  /// In en, this message translates to:
  /// **'Popular Artists'**
  String get popularArtists;

  /// No description provided for @genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get genres;

  /// No description provided for @popularSongs.
  ///
  /// In en, this message translates to:
  /// **'Popular Songs'**
  String get popularSongs;

  /// No description provided for @byArtist.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String byArtist(String name);

  /// No description provided for @noSongsYet.
  ///
  /// In en, this message translates to:
  /// **'No songs yet'**
  String get noSongsYet;

  /// No description provided for @tabRadio.
  ///
  /// In en, this message translates to:
  /// **'Radio'**
  String get tabRadio;

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from Favorites'**
  String get removedFromFavorites;

  /// No description provided for @exploreContent.
  ///
  /// In en, this message translates to:
  /// **'Explore Content'**
  String get exploreContent;

  /// No description provided for @emptyFavoritesMessage.
  ///
  /// In en, this message translates to:
  /// **'Save your favorite stations, songs, podcasts and stories to find them here.'**
  String get emptyFavoritesMessage;

  /// No description provided for @noNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsTitle;

  /// No description provided for @noNotificationsMessage.
  ///
  /// In en, this message translates to:
  /// **'Stay tuned! Your alerts and updates will appear here.'**
  String get noNotificationsMessage;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get enableNotifications;

  /// No description provided for @notificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on'**
  String get notificationsEnabled;

  /// No description provided for @noResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsTitle;

  /// No description provided for @noResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword or explore popular categories below.'**
  String get noResultsMessage;

  /// No description provided for @connectionLostTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Lost'**
  String get connectionLostTitle;

  /// No description provided for @connectionLostMessage.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection and try again to access e-Radio live stream.'**
  String get connectionLostMessage;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @goOffline.
  ///
  /// In en, this message translates to:
  /// **'Go Offline'**
  String get goOffline;

  /// No description provided for @noInternetTitle.
  ///
  /// In en, this message translates to:
  /// **'No Internet Connection'**
  String get noInternetTitle;

  /// No description provided for @noInternetMessage.
  ///
  /// In en, this message translates to:
  /// **'Please connect to Wi-Fi or mobile data to continue listening.'**
  String get noInternetMessage;

  /// No description provided for @newReleasesChannel.
  ///
  /// In en, this message translates to:
  /// **'New releases'**
  String get newReleasesChannel;

  /// No description provided for @newReleasesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new releases'**
  String newReleasesCount(int count);

  /// No description provided for @backOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get backOnline;

  /// No description provided for @unavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailableTitle;

  /// No description provided for @contentUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Unavailable'**
  String get contentUnavailableTitle;

  /// No description provided for @contentUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This content may have been removed or is temporarily unavailable in your region.'**
  String get contentUnavailableMessage;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @reportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report Issue'**
  String get reportIssue;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to save your favorites'**
  String get signInSheetSubtitle;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent Searches'**
  String get recentSearches;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @browseCategories.
  ///
  /// In en, this message translates to:
  /// **'Browse Categories'**
  String get browseCategories;

  /// No description provided for @trendingSearches.
  ///
  /// In en, this message translates to:
  /// **'Trending Searches'**
  String get trendingSearches;

  /// No description provided for @searchSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get searchSongs;

  /// No description provided for @searchRadioStations.
  ///
  /// In en, this message translates to:
  /// **'Radio Stations'**
  String get searchRadioStations;

  /// No description provided for @searchSongsAndEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Songs & Episodes'**
  String get searchSongsAndEpisodes;

  /// No description provided for @removeSearchTerm.
  ///
  /// In en, this message translates to:
  /// **'Remove {term}'**
  String removeSearchTerm(String term);

  /// No description provided for @useSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Search for {term}'**
  String useSuggestion(String term);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'km':
      return AppLocalizationsKm();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
