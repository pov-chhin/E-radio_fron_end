// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'e-Radio';

  @override
  String get navExplore => 'Discover';

  @override
  String get navSearch => 'Search';

  @override
  String get navLibrary => 'Library';

  @override
  String get navFavorite => 'Favorites';

  @override
  String get profile => 'Profile';

  @override
  String get searchHint => 'Search radio, podcasts, songs...';

  @override
  String get liveStations => 'Live Radio Stations';

  @override
  String get onAir => 'On Air';

  @override
  String get onAirNow => 'On Air Now';

  @override
  String get allStations => 'All Stations';

  @override
  String get schedule => 'Schedule';

  @override
  String get listenRadio => 'Listen Radio';

  @override
  String get categories => 'Categories';

  @override
  String get catPodcast => 'Podcast';

  @override
  String get catNews => 'News';

  @override
  String get catHealth => 'Health';

  @override
  String get catEconomy => 'Economy/Finance';

  @override
  String get catSong => 'Song';

  @override
  String get newReleaseFrom => 'New release from';

  @override
  String get notificationsImportant => 'Important';

  @override
  String get notificationsMore => 'More notifications';

  @override
  String get markAllAsRead => 'Mark all as read';

  @override
  String get hideNotification => 'Hide this notification';

  @override
  String showFewerFrom(String name) {
    return 'Show fewer from $name';
  }

  @override
  String turnOffAllFrom(String name) {
    return 'Turn off all from $name';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get catAmbient => 'Ambient Music';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get repeatOff => 'Repeat off';

  @override
  String get repeatAll => 'Repeat all';

  @override
  String get repeatOne => 'Repeat this song';

  @override
  String get equalizer => 'Equalizer';

  @override
  String get equalizerReset => 'Reset';

  @override
  String get equalizerPlayFirst => 'Play a song to adjust the equalizer.';

  @override
  String get equalizerFlat => 'Flat';

  @override
  String get equalizerBassBoost => 'Bass boost';

  @override
  String get equalizerTrebleBoost => 'Treble boost';

  @override
  String get equalizerVocal => 'Vocal';

  @override
  String get equalizerRock => 'Rock';

  @override
  String get equalizerPop => 'Pop';

  @override
  String get equalizerCustom => 'Custom';

  @override
  String get streamUnavailable => 'Stream unavailable';

  @override
  String get openInFacebook => 'Open in Facebook';

  @override
  String get videoCantPlayHere => 'This video can\'t be played in the app';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get nextProgram => 'Next Program';

  @override
  String get todaysPrograms => 'Today\'s Programs';

  @override
  String get replay => 'Replay';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get noProgramsToday => 'No programs scheduled today';

  @override
  String get scheduleLoadFailed => 'Couldn\'t load today\'s programs';

  @override
  String get minimizePlayer => 'Minimize player';

  @override
  String get recentlyPlayed => 'Recently Played';

  @override
  String get noRecentlyPlayed => 'Nothing played yet';

  @override
  String get favorites => 'Favorites';

  @override
  String get noFavorites => 'No favorites yet';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Create Account';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get googleSignInFailed =>
      'Couldn\'t sign in with Google. Please try again.';

  @override
  String get googleSignInCancelled =>
      'Google sign-in didn\'t finish. Please try again.';

  @override
  String googleSignInRefused(String reason) {
    return 'Google sign-in didn\'t finish. Google said: $reason';
  }

  @override
  String get googleSignInClosedEarly =>
      'Google sign-in closed straight away. Make sure a Google account is added to this device, then try again.';

  @override
  String get haveAccount => 'Already have an account?';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signOut => 'Sign Out';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get khmer => 'Khmer';

  @override
  String get preferences => 'Preferences';

  @override
  String get accountInfo => 'Account Info';

  @override
  String get support => 'Support';

  @override
  String get guest => 'Guest';

  @override
  String get preloaderWelcome => 'Welcome to';

  @override
  String preloaderGreetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String preloaderGreetingAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String preloaderGreetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get guestSubtitle => 'Sign in to save favorites and sync your profile';

  @override
  String get station => 'Station';

  @override
  String get frequency => 'Frequency';

  @override
  String get volume => 'Volume';

  @override
  String get emptySearch => 'No stations match your search';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get createYourAccount => 'Create your account';

  @override
  String get joinDate => 'Joined';

  @override
  String get location => 'Location';

  @override
  String get invalidCredentials => 'Invalid email or password';

  @override
  String get accountExists =>
      'An account already exists on this device. Please sign in instead.';

  @override
  String get live => 'Live';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get noStationsPublished => 'No stations published yet';

  @override
  String get noContentYet => 'No content in this category yet';

  @override
  String get seeAll => 'See All';

  @override
  String get address => 'Address';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get save => 'Save';

  @override
  String get accountInfoSaved => 'Account info updated';

  @override
  String get changePassword => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'New items, updates, and profile reminders';

  @override
  String get cancel => 'Cancel';

  @override
  String get jumpBackIn => 'Jump Back In';

  @override
  String get trendingProgram => 'Trending Programs';

  @override
  String get newRelease => 'New Releases';

  @override
  String get share => 'Share';

  @override
  String get settings => 'Settings';

  @override
  String get stop => 'Stop';

  @override
  String get comments => 'Comments';

  @override
  String get writeAComment => 'Write a comment…';

  @override
  String get post => 'Post';

  @override
  String get noCommentsYet => 'No comments yet. Be the first!';

  @override
  String get signInToComment => 'Sign in to join the conversation';

  @override
  String get deleteComment => 'Delete comment';

  @override
  String get bookmark => 'Bookmark';

  @override
  String get addBookmark => 'Add to bookmarks';

  @override
  String get removeBookmark => 'Remove from bookmarks';

  @override
  String get remindMe => 'Remind me';

  @override
  String reminderSetFor(String time) {
    return 'Reminder set for $time';
  }

  @override
  String get cancelReminder => 'Cancel reminder';

  @override
  String get reminderCreated => 'Reminder set';

  @override
  String get reminderCancelled => 'Reminder cancelled';

  @override
  String get notificationsPermissionNeeded =>
      'Allow notifications in system settings to get reminders';

  @override
  String get chooseReminderTime => 'Choose a reminder time';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingDiscoverHeadline => 'Discover Live Radio';

  @override
  String get onboardingDiscoverSubtitle =>
      'Listen to thousands of live stations anytime, anywhere.';

  @override
  String get onboardingPickFavoritesHeadline => 'Pick Your Favorites';

  @override
  String get onboardingPickFavoritesSubtitle =>
      'Choose your favorite genres and stations to get a personalized experience.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get onboardingOneTapHeadline => 'One Tap to Play';

  @override
  String get onboardingOneTapSubtitle =>
      'Find, Save, and jump back into your favorite stations instantly.';

  @override
  String get letsGo => 'Let\'s Go!';

  @override
  String get interestNewsTalk => 'News & Talk';

  @override
  String get interestEducation => 'Education';

  @override
  String get interestSports => 'Sports';

  @override
  String get interestMusic => 'Music';

  @override
  String get interestEconomy => 'Economy';

  @override
  String get interestInfotainment => 'Infotainment';

  @override
  String get interestLifestyle => 'Lifestyle';

  @override
  String get interestRadio => 'Radio';

  @override
  String get interestAmsPrograms => 'AMS Programs';

  @override
  String get interestCulture => 'Culture';

  @override
  String get interestRelaxation => 'Relaxation';

  @override
  String get interestAmbient => 'Ambient';

  @override
  String get interestTrends => 'Trends';

  @override
  String get interestBusiness => 'Business';

  @override
  String get authSubtitle => 'Enter your credentials to continue';

  @override
  String get createAccount => 'Create account';

  @override
  String get emailAddress => 'Email address';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get firstNameHint => 'Enter your first name';

  @override
  String get lastNameHint => 'Enter your last name';

  @override
  String get login => 'Login';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get haveAnAccount => 'Have an account?';

  @override
  String get signInLink => 'Sign in';

  @override
  String get signUpLink => 'Sign up';

  @override
  String get termsPrefix => 'By continuing, you agree to our ';

  @override
  String get termsLink => 'Terms';

  @override
  String get termsAnd => ' and ';

  @override
  String get privacyLink => 'Privacy Policy';

  @override
  String get termsSuffix => '.';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get emailInvalid => 'Enter a valid email address';

  @override
  String get passwordTooShort => 'Use at least 8 characters';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get welcome => 'Welcome';

  @override
  String get orDivider => 'OR';

  @override
  String get account => 'Account';

  @override
  String get yourProfile => 'Your profile';

  @override
  String percentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String get complete => 'Complete';

  @override
  String get incomplete => 'Incomplete';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get helpAndFeedback => 'Help & feedback';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get changeProfilePhoto => 'Change Profile Photo';

  @override
  String get photoUpdated => 'Profile photo updated';

  @override
  String get photoUploadFailed =>
      'Couldn\'t upload the photo. Please try again.';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get requirementsChecklist => 'Requirements Checklist';

  @override
  String get reqLength => 'At least 8 characters long';

  @override
  String get reqNumberOrSymbol => 'Contains at least one number or symbol';

  @override
  String get reqUpperLower => 'Contains upper and lowercase letters';

  @override
  String get updatePassword => 'Update Password';

  @override
  String get forgotCurrentPassword => 'Forgot current password?';

  @override
  String get passwordRequirementsNotMet =>
      'Your new password doesn\'t meet all the requirements';

  @override
  String get allowNotifications => 'Allow notifications';

  @override
  String get notificationsHint => 'Turn on to get the latest updates';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordHeading => 'Forgot Password?';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email address and we will send you a code to reset your password.';

  @override
  String get emailHintLong => 'Enter your email address...';

  @override
  String get sendResetCode => 'Send reset code';

  @override
  String get backTo => 'Back to';

  @override
  String get enterCode => 'Enter code';

  @override
  String get codeSentTo => 'A 6-digit code was sent to';

  @override
  String codeExpiresIn(String time) {
    return 'Code expires in $time';
  }

  @override
  String get codeExpired => 'Code expired';

  @override
  String get didntGetCode => 'Didn\'t get a code?';

  @override
  String get resend => 'Resend';

  @override
  String get invalidCode => 'That code is incorrect or has expired';

  @override
  String get codeResent => 'A new code is on its way';

  @override
  String get pleaseWaitAndRetry =>
      'Too many attempts. Please wait a moment and try again.';

  @override
  String get couldntReachServer =>
      'Couldn\'t reach the server. Check your connection and try again.';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get createNewPassword => 'Create New Password';

  @override
  String get createNewPasswordSubtitle =>
      'Create a new password for your account';

  @override
  String get ruleLength => 'At least 8 characters';

  @override
  String get ruleUppercase => 'At least one uppercase letter';

  @override
  String get ruleNumber => 'At least one number';

  @override
  String get ruleSpecial => 'At least one special character';

  @override
  String get passwordResetDone =>
      'Your password was reset. Sign in with your new password.';

  @override
  String get resetExpired => 'This reset has expired. Please start again.';

  @override
  String get moreOptions => 'More options';

  @override
  String get podcasts => 'Podcasts';

  @override
  String get filterAll => 'All';

  @override
  String get allEpisodes => 'All Episodes';

  @override
  String get playLatest => 'Play Latest';

  @override
  String get follow => 'Follow';

  @override
  String byHost(String name) {
    return 'by $name';
  }

  @override
  String get noPodcastsYet => 'No podcasts yet';

  @override
  String episodeCountBadge(int count) {
    return '$count EP';
  }

  @override
  String get noEpisodesYet => 'No episodes yet';

  @override
  String get episodeDetails => 'Details';

  @override
  String get episodesButton => 'Episodes';

  @override
  String get episodeSection => 'Episode';

  @override
  String get seeMore => 'see more';

  @override
  String episodeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mins',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String viewCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString views',
      one: '1 view',
    );
    return '$_temp0';
  }

  @override
  String get episodeToday => 'Today';

  @override
  String episodeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get music => 'Music';

  @override
  String get tabLocal => 'Local';

  @override
  String get tabInternational => 'International';

  @override
  String get popularArtists => 'Popular Artists';

  @override
  String get genres => 'Genres';

  @override
  String get popularSongs => 'Popular Songs';

  @override
  String byArtist(String name) {
    return 'by $name';
  }

  @override
  String get noSongsYet => 'No songs yet';

  @override
  String get tabRadio => 'Radio';

  @override
  String get removedFromFavorites => 'Removed from Favorites';

  @override
  String get exploreContent => 'Explore Content';

  @override
  String get emptyFavoritesMessage =>
      'Save your favorite stations, songs, podcasts and stories to find them here.';

  @override
  String get noNotificationsTitle => 'No notifications yet';

  @override
  String get noNotificationsMessage =>
      'Stay tuned! Your alerts and updates will appear here.';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get notificationsEnabled => 'Notifications are on';

  @override
  String get noResultsTitle => 'No results found';

  @override
  String get noResultsMessage =>
      'Try another keyword or explore popular categories below.';

  @override
  String get connectionLostTitle => 'Connection Lost';

  @override
  String get connectionLostMessage =>
      'Please check your internet connection and try again to access e-Radio live stream.';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get goOffline => 'Go Offline';

  @override
  String get noInternetTitle => 'No Internet Connection';

  @override
  String get noInternetMessage =>
      'Please connect to Wi-Fi or mobile data to continue listening.';

  @override
  String get newReleasesChannel => 'New releases';

  @override
  String newReleasesCount(int count) {
    return '$count new releases';
  }

  @override
  String get backOnline => 'Back online';

  @override
  String get unavailableTitle => 'Unavailable';

  @override
  String get contentUnavailableTitle => 'Content Unavailable';

  @override
  String get contentUnavailableMessage =>
      'This content may have been removed or is temporarily unavailable in your region.';

  @override
  String get goBack => 'Go Back';

  @override
  String get reportIssue => 'Report Issue';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInSheetSubtitle => 'Log in to save your favorites';

  @override
  String get playlist => 'Playlist';

  @override
  String get recentSearches => 'Recent Searches';

  @override
  String get clearAll => 'Clear All';

  @override
  String get browseCategories => 'Browse Categories';

  @override
  String get trendingSearches => 'Trending Searches';

  @override
  String get searchSongs => 'Songs';

  @override
  String get searchRadioStations => 'Radio Stations';

  @override
  String get searchSongsAndEpisodes => 'Songs & Episodes';

  @override
  String removeSearchTerm(String term) {
    return 'Remove $term';
  }

  @override
  String useSuggestion(String term) {
    return 'Search for $term';
  }
}
