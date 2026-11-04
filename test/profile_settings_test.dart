import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/services/api_exception.dart';
import 'package:e_radio/providers/locale_provider.dart';
import 'package:e_radio/providers/notifications_pref_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/providers/theme_mode_provider.dart';
import 'package:e_radio/providers/reminder_provider.dart';
import 'package:e_radio/data/services/reminder_service.dart';
import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/views/screens/profile/change_password_view.dart';
import 'package:e_radio/views/screens/profile/edit_profile_view.dart';
import 'package:e_radio/views/screens/profile/language_view.dart';
import 'package:e_radio/views/screens/profile/login_view.dart';
import 'package:e_radio/data/models/user_profile.dart';
import 'package:e_radio/views/screens/profile/notifications_view.dart';
import 'package:e_radio/views/screens/profile/privacy_policy_view.dart';
import 'package:e_radio/views/screens/profile/profile_view.dart';
import 'package:e_radio/views/screens/profile/signup_view.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';

import 'support/test_fonts.dart';

UserProfile _profile({String? phone, String? address, String? avatar}) =>
    UserProfile(
      id: '1',
      firstName: 'Sok',
      lastName: 'Dara',
      email: 'sok@example.com',
      joinedAt: DateTime(2026, 9, 28),
      phoneNumber: phone,
      address: address,
      avatarUrl: avatar,
    );

/// Stands in for the phone's gallery: "picks" a fixed file, or nothing.
class _FakePicker extends ImagePickerPlatform {
  _FakePicker(this.path);

  final String? path;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => path == null ? null : XFile(path!);
}

/// Records what the screens ask of the API instead of calling it.
class _FakeAuth extends AuthController {
  _FakeAuth(this.initial);

  final UserProfile? initial;
  Map<String, String?>? updateArgs;
  Map<String, String>? passwordArgs;
  Object? passwordError;
  bool signedOut = false;
  String? avatarPath;

  @override
  UserProfile? build() => initial;

  @override
  Future<void> updateAvatar(String filePath) async => avatarPath = filePath;

  @override
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    String? address,
    String? phoneNumber,
  }) async {
    updateArgs = {
      'first': firstName,
      'last': lastName,
      'email': email,
      'address': address,
      'phone': phoneNumber,
    };
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (passwordError != null) throw passwordError!;
    passwordArgs = {'current': currentPassword, 'new': newPassword};
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    state = null;
  }
}

class _FakeReminders extends ReminderService {
  _FakeReminders(this.grant) : super(FlutterLocalNotificationsPlugin());

  final bool grant;

  @override
  Future<bool> requestPermission() async => grant;
}

late _FakeAuth _auth;
late ProviderContainer _container;

/// Opens the Account screen (on top of a stub "explore" page, the way the app
/// pushes it) with every profile sub-screen routed for real.
Future<void> _pump(
  WidgetTester tester, {
  UserProfile? profile,
  String open = '/profile',
  bool grantNotifications = true,
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  _auth = _FakeAuth(profile);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('explore page')),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileView(),
        routes: [
          GoRoute(path: 'login', builder: (c, s) => const LoginView()),
          GoRoute(path: 'signup', builder: (c, s) => const SignUpView()),
          GoRoute(path: 'edit', builder: (c, s) => const EditProfileView()),
          GoRoute(
            path: 'change-password',
            builder: (c, s) => const ChangePasswordView(),
          ),
          GoRoute(path: 'language', builder: (c, s) => const LanguageView()),
          GoRoute(
            path: 'notifications',
            builder: (c, s) => const NotificationsView(),
          ),
          GoRoute(
            path: 'privacy-policy',
            builder: (c, s) => const PrivacyPolicyView(),
          ),
          // Stand-in for the forgotten-password flow, showing what it was handed.
          GoRoute(
            path: 'forgot-password',
            builder: (c, s) => Scaffold(body: Text('forgot page: ${s.extra}')),
          ),
        ],
      ),
    ],
  );

  _container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      authControllerProvider.overrideWith(() => _auth),
      reminderServiceProvider.overrideWithValue(
        _FakeReminders(grantNotifications),
      ),
    ],
  );
  addTearDown(_container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          routerConfig: router,
          locale: ref.watch(localeProvider),
          themeMode: ref.watch(themeModeProvider),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
  router.push(open);
  await tester.pumpAndSettle();
}

Finder _field(int index) => find.byType(TextFormField).at(index);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  group('Account', () {
    testWidgets('shows who you are, the completion prompt and every group', (
      tester,
    ) async {
      await _pump(tester, profile: _profile()); // 3 of 6 fields → 50%

      expect(find.text('Sok Dara'), findsOneWidget);
      expect(find.text('sok@example.com'), findsOneWidget);
      expect(find.text('YOUR PROFILE'), findsOneWidget);
      expect(find.text('50% complete'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);

      expect(find.text('Account'), findsNWidgets(2)); // title + section
      for (final label in [
        'Profile',
        'Incomplete',
        'Change Password',
        'Notifications',
        'Preferences',
        'Language',
        'English',
        'Dark Mode',
        'Support',
        'Help & feedback',
        'Privacy Policy',
        'Sign Out',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('a complete profile drops the prompt and the badge', (
      tester,
    ) async {
      await _pump(
        tester,
        profile: _profile(
          phone: '012345678',
          address: 'Phnom Penh',
          avatar: 'https://example.com/a.png',
        ),
      );

      expect(find.textContaining('% complete'), findsNothing);
      expect(find.text('Incomplete'), findsNothing);
    });

    testWidgets('each row opens its screen', (tester) async {
      await _pump(tester, profile: _profile());

      await _tap(tester, find.text('Profile'));
      expect(find.text('Edit Profile'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Change Password'));
      expect(find.text('Requirements Checklist'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Notifications'));
      expect(find.text('Allow notifications'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Language'));
      expect(find.text('ខ្មែរ'), findsOneWidget);
    });

    testWidgets('the Dark Mode switch is remembered', (tester) async {
      await _pump(tester, profile: _profile());
      expect(_container.read(themeModeProvider), ThemeMode.system);

      await _tap(tester, find.byType(Switch));

      expect(_container.read(themeModeProvider), ThemeMode.dark);
      expect(
        (await SharedPreferences.getInstance()).getString('theme_mode'),
        'dark',
      );

      await _tap(tester, find.byType(Switch));
      expect(_container.read(themeModeProvider), ThemeMode.light);
    });

    testWidgets('Help & feedback says Coming soon', (tester) async {
      await _pump(tester, profile: _profile());

      await _tap(tester, find.text('Help & feedback'));

      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('Privacy Policy opens the policy, and back returns', (
      tester,
    ) async {
      await _pump(tester, profile: _profile());

      await _tap(tester, find.text('Privacy Policy'));
      expect(find.textContaining('Privacy Policy (GDPR)'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Help & feedback'), findsOneWidget);
    });

    testWidgets('Sign Out signs out and leaves the guest view', (tester) async {
      await _pump(tester, profile: _profile());

      await _tap(tester, find.text('Sign Out'));

      expect(_auth.signedOut, isTrue);
      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Sign Out'), findsNothing);
    });

    testWidgets('a guest sees sign-in buttons and no account-only rows', (
      tester,
    ) async {
      await _pump(tester, profile: null);

      expect(find.text('Guest'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Change Password'), findsNothing);
      expect(find.text('Sign Out'), findsNothing);
      // Notifications, Language and Dark Mode are still available to a guest.
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
    });

    testWidgets('the close button returns to where the screen was opened', (
      tester,
    ) async {
      await _pump(tester, profile: _profile());

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('explore page'), findsOneWidget);
    });
  });

  group('Edit Profile', () {
    testWidgets('greys out the email and saves the rest', (tester) async {
      await _pump(
        tester,
        profile: _profile(phone: '012345678'),
        open: '/profile/edit',
      );

      expect(
        tester.widget<TextField>(find.byType(TextField).at(2)).enabled,
        isFalse,
      );

      await tester.enterText(_field(0), '  Sokha ');
      await tester.enterText(_field(4), 'Phnom Penh');
      await _tap(tester, find.text('Save'));

      expect(_auth.updateArgs, {
        'first': 'Sokha',
        'last': 'Dara',
        'email': 'sok@example.com',
        'address': 'Phnom Penh',
        'phone': '012345678',
      });
      expect(find.text('Account info updated'), findsOneWidget);
    });

    testWidgets('needs a first and last name', (tester) async {
      await _pump(tester, profile: _profile(), open: '/profile/edit');

      await tester.enterText(_field(0), '');
      await _tap(tester, find.text('Save'));

      expect(find.text('This field is required'), findsOneWidget);
      expect(_auth.updateArgs, isNull);
    });

    testWidgets('changing the photo uploads the picked image', (tester) async {
      ImagePickerPlatform.instance = _FakePicker('/tmp/me.jpg');
      await _pump(tester, profile: _profile(), open: '/profile/edit');

      await _tap(tester, find.text('Change Profile Photo'));

      expect(_auth.avatarPath, '/tmp/me.jpg');
      expect(find.text('Profile photo updated'), findsOneWidget);
    });

    testWidgets('backing out of the gallery uploads nothing', (tester) async {
      ImagePickerPlatform.instance = _FakePicker(null);
      await _pump(tester, profile: _profile(), open: '/profile/edit');

      await _tap(tester, find.text('Change Profile Photo'));

      expect(_auth.avatarPath, isNull);
    });
  });

  group('Change Password', () {
    Future<void> fill(
      WidgetTester tester, {
      String current = 'oldpass1',
      String next = 'NewPass12',
      String? confirm,
    }) async {
      await tester.enterText(_field(0), current);
      await tester.enterText(_field(1), next);
      await tester.enterText(_field(2), confirm ?? next);
      await tester.pump();
    }

    testWidgets('the checklist ticks off as the new password improves', (
      tester,
    ) async {
      await _pump(
        tester,
        profile: _profile(),
        open: '/profile/change-password',
      );
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      await tester.enterText(
        _field(1),
        'abcdefgh',
      ); // long enough, no digit, no capital
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.enterText(_field(1), 'Abcdefg1'); // all three
      await tester.pump();
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    });

    testWidgets('rejects a password that misses a requirement', (tester) async {
      await _pump(
        tester,
        profile: _profile(),
        open: '/profile/change-password',
      );

      await fill(tester, next: 'alllowercase');
      await _tap(tester, find.text('Update Password'));

      expect(
        find.text("Your new password doesn't meet all the requirements"),
        findsOneWidget,
      );
      expect(_auth.passwordArgs, isNull);
    });

    testWidgets('rejects a confirmation that does not match', (tester) async {
      await _pump(
        tester,
        profile: _profile(),
        open: '/profile/change-password',
      );

      await fill(tester, confirm: 'Different12');
      await _tap(tester, find.text('Update Password'));

      expect(find.text("Passwords don't match"), findsOneWidget);
      expect(_auth.passwordArgs, isNull);
    });

    testWidgets('updates the password and goes back', (tester) async {
      await _pump(
        tester,
        profile: _profile(),
        open: '/profile/change-password',
      );

      await fill(tester);
      await _tap(tester, find.text('Update Password'));

      expect(_auth.passwordArgs, {'current': 'oldpass1', 'new': 'NewPass12'});
      expect(find.text('Password changed'), findsOneWidget);
      expect(find.text('Requirements Checklist'), findsNothing);
    });

    testWidgets('shows the server\'s complaint about the current password', (
      tester,
    ) async {
      await _pump(
        tester,
        profile: _profile(),
        open: '/profile/change-password',
      );
      _auth.passwordError = ApiException(
        'The given data was invalid.',
        fieldErrors: {
          'current_password': ['The current password is incorrect.'],
        },
      );

      await fill(tester);
      await _tap(tester, find.text('Update Password'));

      expect(find.text('The current password is incorrect.'), findsOneWidget);
      expect(find.text('Requirements Checklist'), findsOneWidget); // stayed
    });

    testWidgets('"Forgot current password?" starts the reset flow with '
        'the signed-in email', (tester) async {
      await _pump(
        tester,
        profile: _profile(),
        open: '/profile/change-password',
      );

      await _tap(tester, find.text('Forgot current password?'));

      expect(find.text('forgot page: sok@example.com'), findsOneWidget);
    });
  });

  group('Language', () {
    testWidgets('switches the whole app to Khmer, and English can\'t be left '
        'with nothing on', (tester) async {
      await _pump(tester, profile: _profile(), open: '/profile/language');
      expect(_container.read(localeProvider), const Locale('en'));

      await _tap(tester, find.byType(Switch).last); // ខ្មែរ
      expect(_container.read(localeProvider), const Locale('km'));
      expect(find.text('ភាសា'), findsOneWidget); // the title, now in Khmer

      // Turning the active language off does nothing.
      await _tap(tester, find.byType(Switch).last);
      expect(_container.read(localeProvider), const Locale('km'));

      await _tap(tester, find.byType(Switch).first); // English
      expect(_container.read(localeProvider), const Locale('en'));
    });
  });

  group('Notifications', () {
    testWidgets('can be switched off and back on', (tester) async {
      await _pump(tester, profile: _profile(), open: '/profile/notifications');
      expect(_container.read(notificationsPrefProvider), isTrue);

      await _tap(tester, find.byType(Switch));
      expect(_container.read(notificationsPrefProvider), isFalse);

      await _tap(tester, find.byType(Switch));
      expect(_container.read(notificationsPrefProvider), isTrue);
    });

    testWidgets('stays off, and says why, if the phone refuses permission', (
      tester,
    ) async {
      await _pump(
        tester,
        profile: _profile(),
        open: '/profile/notifications',
        grantNotifications: false,
        prefs: {'notifications_enabled': false},
      );
      expect(_container.read(notificationsPrefProvider), isFalse);

      await _tap(tester, find.byType(Switch));

      expect(_container.read(notificationsPrefProvider), isFalse);
      expect(
        find.text('Allow notifications in system settings to get reminders'),
        findsOneWidget,
      );
    });
  });
}
