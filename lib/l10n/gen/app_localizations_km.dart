// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khmer Central Khmer (`km`).
class AppLocalizationsKm extends AppLocalizations {
  AppLocalizationsKm([String locale = 'km']) : super(locale);

  @override
  String get appTitle => 'e-Radio';

  @override
  String get navExplore => 'រុករក';

  @override
  String get navSearch => 'ស្វែងរក';

  @override
  String get navLibrary => 'បណ្ណាល័យ';

  @override
  String get navFavorite => 'សំណព្វ';

  @override
  String get profile => 'ប្រវត្តិរូប';

  @override
  String get searchHint => 'ស្វែងរកវិទ្យុ ផតឃែស្ត បទចម្រៀង...';

  @override
  String get liveStations => 'ស្ថានីយ៍វិទ្យុផ្សាយផ្ទាល់';

  @override
  String get onAir => 'កំពុងផ្សាយ';

  @override
  String get onAirNow => 'កំពុងផ្សាយឥឡូវនេះ';

  @override
  String get allStations => 'ស្ថានីយទាំងអស់';

  @override
  String get schedule => 'កាលវិភាគ';

  @override
  String get listenRadio => 'ស្តាប់វិទ្យុ';

  @override
  String get categories => 'ប្រភេទ';

  @override
  String get catPodcast => 'ផតឃែស្ត';

  @override
  String get catNews => 'ព័ត៌មាន';

  @override
  String get catHealth => 'សុខភាព';

  @override
  String get catEconomy => 'សេដ្ឋកិច្ច/ហិរញ្ញវត្ថុ';

  @override
  String get catSong => 'បទចម្រៀង';

  @override
  String get newReleaseFrom => 'ចេញថ្មីពី';

  @override
  String get notificationsImportant => 'សំខាន់';

  @override
  String get notificationsMore => 'ការជូនដំណឹងផ្សេងទៀត';

  @override
  String get markAllAsRead => 'សម្គាល់ថាបានអានទាំងអស់';

  @override
  String get hideNotification => 'លាក់ការជូនដំណឹងនេះ';

  @override
  String showFewerFrom(String name) {
    return 'បង្ហាញតិចជាងពី $name';
  }

  @override
  String turnOffAllFrom(String name) {
    return 'បិទទាំងអស់ពី $name';
  }

  @override
  String minutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count នាទីមុន',
    );
    return '$_temp0';
  }

  @override
  String hoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ម៉ោងមុន',
    );
    return '$_temp0';
  }

  @override
  String get catAmbient => 'តន្ត្រីសម្រាក';

  @override
  String get shuffle => 'ចាក់ចៃដន្យ';

  @override
  String get repeatOff => 'មិនចាក់ឡើងវិញ';

  @override
  String get repeatAll => 'ចាក់ឡើងវិញទាំងអស់';

  @override
  String get repeatOne => 'ចាក់បទនេះឡើងវិញ';

  @override
  String get equalizer => 'អេគ្វាលីហ្សែរ';

  @override
  String get equalizerReset => 'កំណត់ឡើងវិញ';

  @override
  String get equalizerPlayFirst => 'សូមចាក់បទចម្រៀងមួយ ដើម្បីកែសម្លេង។';

  @override
  String get equalizerFlat => 'ធម្មតា';

  @override
  String get equalizerBassBoost => 'បន្ថែមបាស';

  @override
  String get equalizerTrebleBoost => 'បន្ថែមសម្លេងស្រួច';

  @override
  String get equalizerVocal => 'សំឡេងសំដី';

  @override
  String get equalizerRock => 'រ៉ក';

  @override
  String get equalizerPop => 'ប៉ុប';

  @override
  String get equalizerCustom => 'កំណត់ដោយខ្លួនឯង';

  @override
  String get streamUnavailable => 'មិនអាចចាក់បានទេ';

  @override
  String get openInFacebook => 'បើកក្នុង Facebook';

  @override
  String get videoCantPlayHere => 'មិនអាចចាក់វីដេអូនេះក្នុងកម្មវិធីបានទេ';

  @override
  String get nowPlaying => 'កំពុងចាក់';

  @override
  String get nextProgram => 'កម្មវិធីបន្ទាប់';

  @override
  String get todaysPrograms => 'កម្មវិធីផ្សាយថ្ងៃនេះ';

  @override
  String get replay => 'ចាក់ឡើងវិញ';

  @override
  String get tomorrow => 'ថ្ងៃស្អែក';

  @override
  String get noProgramsToday => 'គ្មានកម្មវិធីផ្សាយថ្ងៃនេះទេ';

  @override
  String get scheduleLoadFailed => 'មិនអាចផ្ទុកកម្មវិធីថ្ងៃនេះបានទេ';

  @override
  String get minimizePlayer => 'បង្រួមកម្មវិធីចាក់';

  @override
  String get recentlyPlayed => 'បានចាក់ថ្មីៗ';

  @override
  String get noRecentlyPlayed => 'មិនទាន់មានប្រវត្តិចាក់ទេ';

  @override
  String get favorites => 'សំណព្វ';

  @override
  String get noFavorites => 'មិនទាន់មានសំណព្វទេ';

  @override
  String get addToFavorites => 'បន្ថែមទៅសំណព្វ';

  @override
  String get removeFromFavorites => 'លុបចេញពីសំណព្វ';

  @override
  String get play => 'ចាក់';

  @override
  String get pause => 'ផ្អាក';

  @override
  String get retry => 'ព្យាយាមម្ដងទៀត';

  @override
  String get loading => 'កំពុងផ្ទុក';

  @override
  String get signIn => 'ចូលគណនី';

  @override
  String get signUp => 'បង្កើតគណនី';

  @override
  String get continueWithGoogle => 'បន្តជាមួយ Google';

  @override
  String get comingSoon => 'នឹងមកដល់ឆាប់ៗនេះ';

  @override
  String get googleSignInFailed =>
      'មិនអាចចូលដោយប្រើ Google បានទេ។ សូមព្យាយាមម្ដងទៀត។';

  @override
  String get googleSignInCancelled =>
      'ការចូលដោយ Google មិនបានបញ្ចប់ទេ។ សូមព្យាយាមម្ដងទៀត។';

  @override
  String googleSignInRefused(String reason) {
    return 'ការចូលដោយ Google មិនបានបញ្ចប់ទេ។ Google បានឆ្លើយថា៖ $reason';
  }

  @override
  String get googleSignInClosedEarly =>
      'ការចូលដោយ Google បានបិទភ្លាមៗ។ សូមប្រាកដថាបានបន្ថែមគណនី Google ក្នុងឧបករណ៍នេះ រួចព្យាយាមម្ដងទៀត។';

  @override
  String get haveAccount => 'មានគណនីរួចហើយ?';

  @override
  String get noAccount => 'មិនទាន់មានគណនី?';

  @override
  String get email => 'អ៊ីមែល';

  @override
  String get password => 'ពាក្យសម្ងាត់';

  @override
  String get signOut => 'ចាកចេញ';

  @override
  String get language => 'ភាសា';

  @override
  String get english => 'អង់គ្លេស';

  @override
  String get khmer => 'ខ្មែរ';

  @override
  String get preferences => 'ការកំណត់';

  @override
  String get accountInfo => 'ព័ត៌មានគណនី';

  @override
  String get support => 'ជំនួយ';

  @override
  String get guest => 'ភ្ញៀវ';

  @override
  String get preloaderWelcome => 'សូមស្វាគមន៍មកកាន់';

  @override
  String preloaderGreetingMorning(String name) {
    return 'អរុណសួស្តី $name';
  }

  @override
  String preloaderGreetingAfternoon(String name) {
    return 'ទិវាសួស្តី $name';
  }

  @override
  String preloaderGreetingEvening(String name) {
    return 'សាយណ្ហសួស្តី $name';
  }

  @override
  String get guestSubtitle =>
      'ចូលគណនីដើម្បីរក្សាទុកសំណព្វ និងធ្វើសមកាលកម្មប្រវត្តិរូបរបស់អ្នក';

  @override
  String get station => 'ស្ថានីយ៍';

  @override
  String get frequency => 'ប្រេកង់';

  @override
  String get volume => 'សំឡេង';

  @override
  String get emptySearch => 'រកមិនឃើញស្ថានីយ៍ដែលត្រូវនឹងការស្វែងរករបស់អ្នកទេ';

  @override
  String get welcomeBack => 'សូមស្វាគមន៍ការត្រឡប់មកវិញ';

  @override
  String get createYourAccount => 'បង្កើតគណនីរបស់អ្នក';

  @override
  String get joinDate => 'ចូលរួមនៅ';

  @override
  String get location => 'ទីតាំង';

  @override
  String get invalidCredentials => 'អ៊ីមែល ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវ';

  @override
  String get accountExists =>
      'គណនីមួយមានរួចហើយនៅលើឧបករណ៍នេះ។ សូមចូលគណនីជំនួសវិញ។';

  @override
  String get live => 'កំពុងផ្សាយផ្ទាល់';

  @override
  String get firstName => 'នាមខ្លួន';

  @override
  String get lastName => 'នាមត្រកូល';

  @override
  String get noStationsPublished => 'មិនទាន់មានស្ថានីយ៍បានផ្សាយនៅឡើយទេ';

  @override
  String get noContentYet => 'មិនទាន់មានមាតិកានៅក្នុងប្រភេទនេះទេ';

  @override
  String get seeAll => 'មើលទាំងអស់';

  @override
  String get address => 'អាសយដ្ឋាន';

  @override
  String get phoneNumber => 'លេខទូរស័ព្ទ';

  @override
  String get save => 'រក្សាទុក';

  @override
  String get accountInfoSaved => 'ព័ត៌មានគណនីត្រូវបានធ្វើបច្ចុប្បន្នភាព';

  @override
  String get changePassword => 'ប្តូរពាក្យសម្ងាត់';

  @override
  String get currentPassword => 'ពាក្យសម្ងាត់បច្ចុប្បន្ន';

  @override
  String get newPassword => 'ពាក្យសម្ងាត់ថ្មី';

  @override
  String get passwordChanged => 'ពាក្យសម្ងាត់ត្រូវបានប្តូរ';

  @override
  String get notifications => 'ការជូនដំណឹង';

  @override
  String get notificationsSubtitle =>
      'ធាតុថ្មី ការធ្វើបច្ចុប្បន្នភាព និងការរំលឹកអំពីប្រវត្តិរូប';

  @override
  String get cancel => 'បោះបង់';

  @override
  String get jumpBackIn => 'បន្តស្តាប់';

  @override
  String get trendingProgram => 'កម្មវិធីពេញនិយម';

  @override
  String get newRelease => 'ថ្មីៗ';

  @override
  String get share => 'ចែករំលែក';

  @override
  String get settings => 'ការកំណត់';

  @override
  String get stop => 'បញ្ឈប់';

  @override
  String get comments => 'មតិយោបល់';

  @override
  String get writeAComment => 'សរសេរមតិយោបល់…';

  @override
  String get post => 'បញ្ជូន';

  @override
  String get noCommentsYet => 'មិនទាន់មានមតិយោបល់ទេ។ សូមធ្វើជាអ្នកដំបូង!';

  @override
  String get signInToComment => 'ចូលគណនីដើម្បីចូលរួមសន្ទនា';

  @override
  String get deleteComment => 'លុបមតិយោបល់';

  @override
  String get bookmark => 'ចំណាំ';

  @override
  String get addBookmark => 'បន្ថែមទៅចំណាំ';

  @override
  String get removeBookmark => 'លុបចេញពីចំណាំ';

  @override
  String get remindMe => 'រំលឹកខ្ញុំ';

  @override
  String reminderSetFor(String time) {
    return 'បានកំណត់ការរំលឹកសម្រាប់ $time';
  }

  @override
  String get cancelReminder => 'បោះបង់ការរំលឹក';

  @override
  String get reminderCreated => 'បានកំណត់ការរំលឹក';

  @override
  String get reminderCancelled => 'បានបោះបង់ការរំលឹក';

  @override
  String get notificationsPermissionNeeded =>
      'សូមអនុញ្ញាតការជូនដំណឹងក្នុងការកំណត់ប្រព័ន្ធ ដើម្បីទទួលការរំលឹក';

  @override
  String get chooseReminderTime => 'ជ្រើសរើសពេលវេលារំលឹក';

  @override
  String get onboardingSkip => 'រំលង';

  @override
  String get onboardingDiscoverHeadline => 'ស្វែងរកវិទ្យុផ្សាយផ្ទាល់';

  @override
  String get onboardingDiscoverSubtitle =>
      'ស្តាប់ស្ថានីយ៍រាប់ពាន់ ពេលណាក៏បាន នៅទីណាក៏បាន។';

  @override
  String get onboardingPickFavoritesHeadline => 'ជ្រើសរើសចំណូលចិត្តរបស់អ្នក';

  @override
  String get onboardingPickFavoritesSubtitle =>
      'ជ្រើសរើសប្រភេទ និងស្ថានីយ៍ដែលអ្នកចូលចិត្ត ដើម្បីទទួលបានបទពិសោធន៍ផ្ទាល់ខ្លួន។';

  @override
  String get continueLabel => 'បន្ត';

  @override
  String get onboardingOneTapHeadline => 'ចុចម្តង ចាក់ភ្លាម';

  @override
  String get onboardingOneTapSubtitle =>
      'ស្វែងរក រក្សាទុក និងបន្តស្តាប់ស្ថានីយ៍ដែលអ្នកចូលចិត្តភ្លាមៗ។';

  @override
  String get letsGo => 'ចាប់ផ្តើម!';

  @override
  String get interestNewsTalk => 'ព័ត៌មាន និងការពិភាក្សា';

  @override
  String get interestEducation => 'អប់រំ';

  @override
  String get interestSports => 'កីឡា';

  @override
  String get interestMusic => 'តន្ត្រី';

  @override
  String get interestEconomy => 'សេដ្ឋកិច្ច';

  @override
  String get interestInfotainment => 'ព័ត៌មានកម្សាន្ត';

  @override
  String get interestLifestyle => 'របៀបរស់នៅ';

  @override
  String get interestRadio => 'វិទ្យុ';

  @override
  String get interestAmsPrograms => 'កម្មវិធី AMS';

  @override
  String get interestCulture => 'វប្បធម៌';

  @override
  String get interestRelaxation => 'សម្រាក';

  @override
  String get interestAmbient => 'តន្ត្រីបរិយាកាស';

  @override
  String get interestTrends => 'និន្នាការ';

  @override
  String get interestBusiness => 'ធុរកិច្ច';

  @override
  String get authSubtitle => 'បញ្ចូលព័ត៌មានគណនីរបស់អ្នកដើម្បីបន្ត';

  @override
  String get createAccount => 'បង្កើតគណនី';

  @override
  String get emailAddress => 'អាសយដ្ឋានអ៊ីមែល';

  @override
  String get confirmPassword => 'បញ្ជាក់ពាក្យសម្ងាត់';

  @override
  String get firstNameHint => 'បញ្ចូលនាមខ្លួនរបស់អ្នក';

  @override
  String get lastNameHint => 'បញ្ចូលនាមត្រកូលរបស់អ្នក';

  @override
  String get login => 'ចូលគណនី';

  @override
  String get forgotPassword => 'ភ្លេចពាក្យសម្ងាត់?';

  @override
  String get haveAnAccount => 'មានគណនីហើយ?';

  @override
  String get signInLink => 'ចូលគណនី';

  @override
  String get signUpLink => 'បង្កើតគណនី';

  @override
  String get termsPrefix => 'តាមរយៈការបន្ត អ្នកយល់ព្រមនឹង';

  @override
  String get termsLink => 'លក្ខខណ្ឌប្រើប្រាស់';

  @override
  String get termsAnd => ' និង ';

  @override
  String get privacyLink => 'គោលការណ៍ឯកជនភាព';

  @override
  String get termsSuffix => '។';

  @override
  String get fieldRequired => 'តម្រូវឱ្យបំពេញ';

  @override
  String get emailInvalid => 'សូមបញ្ចូលអាសយដ្ឋានអ៊ីមែលឱ្យត្រឹមត្រូវ';

  @override
  String get passwordTooShort => 'ត្រូវមានយ៉ាងហោចណាស់ ៨ តួអក្សរ';

  @override
  String get passwordsDontMatch => 'ពាក្យសម្ងាត់មិនត្រូវគ្នា';

  @override
  String get showPassword => 'បង្ហាញពាក្យសម្ងាត់';

  @override
  String get hidePassword => 'លាក់ពាក្យសម្ងាត់';

  @override
  String get welcome => 'សូមស្វាគមន៍';

  @override
  String get orDivider => 'ឬ';

  @override
  String get account => 'គណនី';

  @override
  String get yourProfile => 'ប្រវត្តិរូបរបស់អ្នក';

  @override
  String percentComplete(int percent) {
    return 'បានបំពេញ $percent%';
  }

  @override
  String get complete => 'បំពេញ';

  @override
  String get incomplete => 'មិនទាន់ពេញលេញ';

  @override
  String get darkMode => 'របៀបងងឹត';

  @override
  String get helpAndFeedback => 'ជំនួយ និងមតិកែលម្អ';

  @override
  String get editProfile => 'កែប្រែប្រវត្តិរូប';

  @override
  String get changeProfilePhoto => 'ប្តូររូបភាពប្រវត្តិរូប';

  @override
  String get photoUpdated => 'បានធ្វើបច្ចុប្បន្នភាពរូបភាពប្រវត្តិរូប';

  @override
  String get photoUploadFailed => 'មិនអាចបញ្ចូលរូបភាពបានទេ។ សូមព្យាយាមម្តងទៀត។';

  @override
  String get confirmNewPassword => 'បញ្ជាក់ពាក្យសម្ងាត់ថ្មី';

  @override
  String get requirementsChecklist => 'តម្រូវការពាក្យសម្ងាត់';

  @override
  String get reqLength => 'យ៉ាងហោចណាស់ ៨ តួអក្សរ';

  @override
  String get reqNumberOrSymbol => 'មានលេខ ឬនិមិត្តសញ្ញាយ៉ាងហោចណាស់មួយ';

  @override
  String get reqUpperLower => 'មានអក្សរធំ និងអក្សរតូច';

  @override
  String get updatePassword => 'ធ្វើបច្ចុប្បន្នភាពពាក្យសម្ងាត់';

  @override
  String get forgotCurrentPassword => 'ភ្លេចពាក្យសម្ងាត់បច្ចុប្បន្ន?';

  @override
  String get passwordRequirementsNotMet =>
      'ពាក្យសម្ងាត់ថ្មីមិនបំពេញតាមតម្រូវការទាំងអស់';

  @override
  String get allowNotifications => 'អនុញ្ញាតការជូនដំណឹង';

  @override
  String get notificationsHint => 'បើកដើម្បីទទួលបានព័ត៌មានថ្មីៗ';

  @override
  String get forgotPasswordTitle => 'ភ្លេចពាក្យសម្ងាត់';

  @override
  String get forgotPasswordHeading => 'ភ្លេចពាក្យសម្ងាត់?';

  @override
  String get forgotPasswordSubtitle =>
      'បញ្ចូលអាសយដ្ឋានអ៊ីមែលរបស់អ្នក ហើយយើងនឹងផ្ញើលេខកូដសម្រាប់កំណត់ពាក្យសម្ងាត់ឡើងវិញ។';

  @override
  String get emailHintLong => 'បញ្ចូលអាសយដ្ឋានអ៊ីមែលរបស់អ្នក...';

  @override
  String get sendResetCode => 'ផ្ញើលេខកូដកំណត់ឡើងវិញ';

  @override
  String get backTo => 'ត្រឡប់ទៅ';

  @override
  String get enterCode => 'បញ្ចូលលេខកូដ';

  @override
  String get codeSentTo => 'លេខកូដ ៦ ខ្ទង់ត្រូវបានផ្ញើទៅ';

  @override
  String codeExpiresIn(String time) {
    return 'លេខកូដផុតកំណត់ក្នុងរយៈពេល $time';
  }

  @override
  String get codeExpired => 'លេខកូដផុតកំណត់';

  @override
  String get didntGetCode => 'មិនបានទទួលលេខកូដទេ?';

  @override
  String get resend => 'ផ្ញើម្ដងទៀត';

  @override
  String get invalidCode => 'លេខកូដមិនត្រឹមត្រូវ ឬបានផុតកំណត់';

  @override
  String get codeResent => 'លេខកូដថ្មីកំពុងត្រូវបានផ្ញើ';

  @override
  String get pleaseWaitAndRetry =>
      'ព្យាយាមច្រើនពេក។ សូមរង់ចាំបន្តិច ហើយព្យាយាមម្ដងទៀត។';

  @override
  String get couldntReachServer =>
      'មិនអាចភ្ជាប់ទៅម៉ាស៊ីនមេបានទេ។ សូមពិនិត្យការតភ្ជាប់របស់អ្នក ហើយព្យាយាមម្ដងទៀត។';

  @override
  String get resetPassword => 'កំណត់ពាក្យសម្ងាត់ឡើងវិញ';

  @override
  String get createNewPassword => 'បង្កើតពាក្យសម្ងាត់ថ្មី';

  @override
  String get createNewPasswordSubtitle =>
      'បង្កើតពាក្យសម្ងាត់ថ្មីសម្រាប់គណនីរបស់អ្នក';

  @override
  String get ruleLength => 'យ៉ាងហោចណាស់ ៨ តួអក្សរ';

  @override
  String get ruleUppercase => 'យ៉ាងហោចណាស់អក្សរធំមួយ';

  @override
  String get ruleNumber => 'យ៉ាងហោចណាស់លេខមួយ';

  @override
  String get ruleSpecial => 'យ៉ាងហោចណាស់និមិត្តសញ្ញាពិសេសមួយ';

  @override
  String get passwordResetDone =>
      'ពាក្យសម្ងាត់របស់អ្នកត្រូវបានកំណត់ឡើងវិញ។ សូមចូលគណនីដោយប្រើពាក្យសម្ងាត់ថ្មី។';

  @override
  String get resetExpired =>
      'ការកំណត់ឡើងវិញនេះបានផុតកំណត់។ សូមចាប់ផ្តើមម្ដងទៀត។';

  @override
  String get moreOptions => 'ជម្រើសបន្ថែម';

  @override
  String get podcasts => 'ផតឃែស្ត';

  @override
  String get filterAll => 'ទាំងអស់';

  @override
  String get allEpisodes => 'ភាគទាំងអស់';

  @override
  String get playLatest => 'ចាក់ភាគចុងក្រោយ';

  @override
  String get follow => 'តាមដាន';

  @override
  String byHost(String name) {
    return 'ដោយ $name';
  }

  @override
  String get noPodcastsYet => 'មិនទាន់មានផតឃែស្តទេ';

  @override
  String episodeCountBadge(int count) {
    return '$count ភាគ';
  }

  @override
  String get noEpisodesYet => 'មិនទាន់មានភាគទេ';

  @override
  String get episodeDetails => 'ព័ត៌មានលម្អិត';

  @override
  String get episodesButton => 'ភាគ';

  @override
  String get episodeSection => 'ភាគ';

  @override
  String get seeMore => 'មើលបន្ថែម';

  @override
  String episodeMinutes(int count) {
    return '$count នាទី';
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
      other: 'មើល $countString ដង',
    );
    return '$_temp0';
  }

  @override
  String get episodeToday => 'ថ្ងៃនេះ';

  @override
  String episodeDaysAgo(int count) {
    return '$count ថ្ងៃមុន';
  }

  @override
  String get music => 'តន្ត្រី';

  @override
  String get tabLocal => 'ក្នុងស្រុក';

  @override
  String get tabInternational => 'អន្តរជាតិ';

  @override
  String get popularArtists => 'សិល្បករពេញនិយម';

  @override
  String get genres => 'ប្រភេទតន្ត្រី';

  @override
  String get popularSongs => 'ចម្រៀងពេញនិយម';

  @override
  String byArtist(String name) {
    return 'ដោយ $name';
  }

  @override
  String get noSongsYet => 'មិនទាន់មានចម្រៀងទេ';

  @override
  String get tabRadio => 'វិទ្យុ';

  @override
  String get removedFromFavorites => 'បានលុបចេញពីសំណព្វ';

  @override
  String get exploreContent => 'រុករកមាតិកា';

  @override
  String get emptyFavoritesMessage =>
      'រក្សាទុកស្ថានីយ ចម្រៀង ផតឃែស្ត និងរឿងដែលអ្នកចូលចិត្ត ដើម្បីរកឃើញវានៅទីនេះ។';

  @override
  String get noNotificationsTitle => 'មិនទាន់មានការជូនដំណឹងទេ';

  @override
  String get noNotificationsMessage =>
      'សូមរង់ចាំ! ការជូនដំណឹង និងព័ត៌មានថ្មីៗនឹងបង្ហាញនៅទីនេះ។';

  @override
  String get enableNotifications => 'បើកការជូនដំណឹង';

  @override
  String get notificationsEnabled => 'ការជូនដំណឹងត្រូវបានបើក';

  @override
  String get noResultsTitle => 'រកមិនឃើញលទ្ធផលទេ';

  @override
  String get noResultsMessage =>
      'សាកល្បងពាក្យគន្លឹះផ្សេង ឬស្វែងរកប្រភេទពេញនិយមខាងក្រោម។';

  @override
  String get connectionLostTitle => 'បាត់បង់ការតភ្ជាប់';

  @override
  String get connectionLostMessage =>
      'សូមពិនិត្យការតភ្ជាប់អ៊ីនធឺណិតរបស់អ្នក ហើយព្យាយាមម្តងទៀតដើម្បីចូលប្រើការផ្សាយផ្ទាល់ e-Radio។';

  @override
  String get tryAgain => 'ព្យាយាមម្តងទៀត';

  @override
  String get goOffline => 'បន្តដោយគ្មានអ៊ីនធឺណិត';

  @override
  String get noInternetTitle => 'គ្មានការតភ្ជាប់អ៊ីនធឺណិត';

  @override
  String get noInternetMessage =>
      'សូមភ្ជាប់ Wi-Fi ឬទិន្នន័យទូរសព្ទ ដើម្បីបន្តស្តាប់។';

  @override
  String get newReleasesChannel => 'ការចេញផ្សាយថ្មី';

  @override
  String newReleasesCount(int count) {
    return 'ការចេញផ្សាយថ្មី $count';
  }

  @override
  String get backOnline => 'បានតភ្ជាប់ឡើងវិញ';

  @override
  String get unavailableTitle => 'មិនអាចប្រើបាន';

  @override
  String get contentUnavailableTitle => 'មាតិកាមិនអាចប្រើបាន';

  @override
  String get contentUnavailableMessage =>
      'មាតិកានេះប្រហែលជាត្រូវបានដកចេញ ឬមិនអាចប្រើបានជាបណ្តោះអាសន្ននៅក្នុងតំបន់របស់អ្នក។';

  @override
  String get goBack => 'ត្រឡប់ក្រោយ';

  @override
  String get reportIssue => 'រាយការណ៍បញ្ហា';

  @override
  String get signInTitle => 'ចូលគណនី';

  @override
  String get signInSheetSubtitle => 'ចូលគណនីដើម្បីរក្សាទុកសំណព្វរបស់អ្នក';

  @override
  String get playlist => 'បញ្ជីចាក់';

  @override
  String get recentSearches => 'ការស្វែងរកថ្មីៗ';

  @override
  String get clearAll => 'សម្អាតទាំងអស់';

  @override
  String get browseCategories => 'រកមើលតាមប្រភេទ';

  @override
  String get trendingSearches => 'ការស្វែងរកពេញនិយម';

  @override
  String get searchSongs => 'បទចម្រៀង';

  @override
  String get searchRadioStations => 'ស្ថានីយ៍វិទ្យុ';

  @override
  String get searchSongsAndEpisodes => 'បទចម្រៀង និងវគ្គ';

  @override
  String removeSearchTerm(String term) {
    return 'លុប $term';
  }

  @override
  String useSuggestion(String term) {
    return 'ស្វែងរក $term';
  }
}
