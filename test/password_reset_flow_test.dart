import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/services/api_exception.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/core/supports/mask_email.dart';
import 'package:e_radio/data/repositories/password_reset_repository.dart';
import 'package:e_radio/views/screens/password_reset/enter_code_view.dart';
import 'package:e_radio/views/screens/password_reset/forgot_password_view.dart';
import 'package:e_radio/data/models/password_reset_args.dart';
import 'package:e_radio/views/screens/password_reset/reset_password_view.dart';
import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/data/models/user_profile.dart';
import 'package:e_radio/views/widgets/profile/password_requirements.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';

import 'support/test_fonts.dart';

/// Answers the three endpoints from memory and records what it was asked.
class _FakeRepo implements PasswordResetRepository {
  final requests = <String>[];
  final verifications = <({String email, String code})>[];
  final resets = <({String email, String token, String password})>[];

  int expiresIn = 120;
  String token = 'reset-token-1';
  Object? requestError;
  Object? verifyError;
  Object? resetError;

  /// When set, verifyCode waits for it — a request that takes real time, as on
  /// a phone, rather than answering before the next frame.
  Completer<void>? verifyGate;

  @override
  Future<int> requestCode(String email) async {
    requests.add(email);
    if (requestError != null) throw requestError!;
    return expiresIn;
  }

  @override
  Future<String> verifyCode({
    required String email,
    required String code,
  }) async {
    verifications.add((email: email, code: code));
    await verifyGate?.future;
    if (verifyError != null) throw verifyError!;
    return token;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String password,
  }) async {
    resets.add((email: email, token: resetToken, password: password));
    if (resetError != null) throw resetError!;
  }
}

class _FakeAuth extends AuthController {
  _FakeAuth(this.initial);

  final UserProfile? initial;
  bool signedOut = false;

  @override
  UserProfile? build() => initial;

  @override
  Future<void> signOut() async {
    signedOut = true;
    state = null;
  }
}

final _signedInUser = UserProfile(
  id: '1',
  firstName: 'Jane',
  lastName: 'Doe',
  email: 'jane@gmail.com',
  joinedAt: DateTime(2026, 9, 28),
);

late _FakeRepo _repo;
late _FakeAuth _auth;

/// Pumps the flow's real screens, routed like the app's, with stubs for the
/// pages around it. [open] is pushed on top of a "home" page.
Future<GoRouter> _pump(
  WidgetTester tester, {
  required String open,
  Object? extra,
  UserProfile? user,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  _repo = _FakeRepo();
  _auth = _FakeAuth(user);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/profile/login',
        builder: (c, s) => const Scaffold(body: Text('login page')),
      ),
      GoRoute(
        path: '/profile/forgot-password',
        builder: (c, s) => ForgotPasswordView(
          initialEmail: s.extra is String ? s.extra as String : null,
        ),
        routes: [
          GoRoute(
            path: 'code',
            builder: (c, s) => EnterCodeView(args: s.extra as ResetCodeArgs),
          ),
          GoRoute(
            path: 'reset',
            builder: (c, s) =>
                ResetPasswordView(args: s.extra as ResetPasswordArgs),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authControllerProvider.overrideWith(() => _auth),
        passwordResetRepositoryProvider.overrideWithValue(_repo),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  router.push(open, extra: extra);
  await _settle(tester);
  return router;
}

/// The code screen's countdown keeps ticking, so pumpAndSettle would run it
/// down to zero; advance just far enough for async work and page transitions.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

const _codeArgs = ResetCodeArgs(email: 'jane@gmail.com', expiresIn: 120);
const _resetArgs = ResetPasswordArgs(
  email: 'jane@gmail.com',
  resetToken: 'reset-token-1',
);

void main() {
  setUpAll(loadTestFonts);

  group('maskEmail', () {
    test('keeps the first letter and the domain, hides the rest', () {
      expect(maskEmail('jane@gmail.com'), 'j••••@gmail.com');
      expect(maskEmail('a.very.long.name@example.org'), 'a••••@example.org');
    });

    test('leaves something that is not an email alone', () {
      expect(maskEmail('not-an-email'), 'not-an-email');
      expect(maskEmail('@nothing-before'), '@nothing-before');
      expect(maskEmail(''), '');
    });
  });

  group('PasswordRules.reset', () {
    test('needs all four: 8+ characters, uppercase, number, special', () {
      bool ok(String p) => PasswordRules.allMet(PasswordRules.reset, p);

      expect(ok('NewPass1!'), isTrue);
      expect(ok('Ab1!'), isFalse, reason: 'too short');
      expect(ok('newpass1!'), isFalse, reason: 'no uppercase');
      expect(ok('NewPass!!'), isFalse, reason: 'no number');
      expect(ok('NewPass12'), isFalse, reason: 'no special character');
    });

    test('treats a space as special, as the server does', () {
      expect(PasswordRules.hasSpecial('Pass word1'), isTrue);
    });
  });

  group('Forgot Password', () {
    testWidgets('shows the designed screen', (tester) async {
      await _pump(tester, open: '/profile/forgot-password');

      expect(find.text('Forgot Password'), findsOneWidget); // app bar
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.textContaining('send you a code'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Enter your email address...'), findsOneWidget);
      expect(find.text('Send reset code'), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);
      expect(find.textContaining('Back to'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('carries over an email that was already typed', (tester) async {
      await _pump(
        tester,
        open: '/profile/forgot-password',
        extra: 'jane@gmail.com',
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'jane@gmail.com',
      );
    });

    testWidgets('rejects something that is not an email', (tester) async {
      await _pump(tester, open: '/profile/forgot-password');

      await tester.enterText(find.byType(TextField), 'nope');
      await _tapText(tester, 'Send reset code');

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(_repo.requests, isEmpty);
    });

    testWidgets('asks for a code and moves to Enter code', (tester) async {
      await _pump(tester, open: '/profile/forgot-password');

      await tester.enterText(find.byType(TextField), '  jane@gmail.com ');
      await _tapText(tester, 'Send reset code');

      expect(_repo.requests, ['jane@gmail.com']);
      expect(find.text('Enter code'), findsOneWidget);
      expect(find.text('j••••@gmail.com'), findsOneWidget);
    });

    testWidgets('says to wait when the server is rate limiting', (
      tester,
    ) async {
      await _pump(tester, open: '/profile/forgot-password');
      _repo.requestError = ApiException('Too Many Attempts.', statusCode: 429);

      await tester.enterText(find.byType(TextField), 'jane@gmail.com');
      await _tapText(tester, 'Send reset code');

      expect(
        find.text('Too many attempts. Please wait a moment and try again.'),
        findsOneWidget,
      );
      expect(find.text('Enter code'), findsNothing);
    });

    testWidgets('"Back to Sign in" returns to Sign In', (tester) async {
      await _pump(tester, open: '/profile/forgot-password');

      await _tapText(tester, 'Sign in');

      expect(find.text('login page'), findsOneWidget);
    });

    testWidgets('a signed-in person is not offered "Back to Sign in"', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password',
        user: _signedInUser,
      );

      expect(find.text('Sign in'), findsNothing);
    });
  });

  group('Enter code', () {
    testWidgets('shows the designed screen', (tester) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/code',
        extra: _codeArgs,
      );

      expect(find.text('Enter code'), findsOneWidget);
      expect(find.text('A 6-digit code was sent to'), findsOneWidget);
      expect(find.text('j••••@gmail.com'), findsOneWidget);
      expect(find.text('Code expires in 2:00'), findsOneWidget);
      expect(find.textContaining("Didn't get a code?"), findsOneWidget);
      expect(find.text('Resend'), findsOneWidget);
    });

    testWidgets('counts down, then locks and says the code expired', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/code',
        extra: _codeArgs,
      );

      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Code expires in 0:59'), findsOneWidget);

      await tester.pump(const Duration(seconds: 60));
      expect(find.text('Code expired'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('checks the code the moment the sixth digit is typed', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/code',
        extra: _codeArgs,
      );

      await tester.enterText(find.byType(TextField), '12345');
      await _settle(tester);
      expect(_repo.verifications, isEmpty, reason: 'five digits is not enough');

      await tester.enterText(find.byType(TextField), '123456');
      await _settle(tester);

      expect(_repo.verifications, [(email: 'jane@gmail.com', code: '123456')]);
      expect(find.text('Create New Password'), findsOneWidget);
    });

    testWidgets('a wrong code says so and clears the boxes', (tester) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/code',
        extra: _codeArgs,
      );
      _repo.verifyError = ApiException(
        'The given data was invalid.',
        statusCode: 422,
        fieldErrors: {
          'code': ['That code is incorrect or has expired.'],
        },
      );

      await tester.enterText(find.byType(TextField), '000000');
      await _settle(tester);

      expect(
        find.text('That code is incorrect or has expired'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(find.text('Create New Password'), findsNothing);
    });

    testWidgets(
      'a code that cannot be checked says so and can be typed again',
      (tester) async {
        await _pump(
          tester,
          open: '/profile/forgot-password/code',
          extra: _codeArgs,
        );
        // No connection, or a reply that is not JSON: not an ApiException.
        _repo.verifyError = const SocketException('Failed host lookup');

        await tester.enterText(find.byType(TextField), '123456');
        await _settle(tester);

        expect(
          find.text(
            "Couldn't reach the server. Check your connection and try again.",
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );

        // The same code can go in again once the connection is back.
        _repo.verifyError = null;
        await tester.enterText(find.byType(TextField), '123456');
        await _settle(tester);

        expect(_repo.verifications.length, 2);
        expect(find.text('Create New Password'), findsOneWidget);
      },
    );

    testWidgets('the boxes keep the keyboard while a code is being checked', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/code',
        extra: _codeArgs,
      );
      _repo.verifyGate = Completer<void>();
      _repo.verifyError = ApiException(
        'The given data was invalid.',
        statusCode: 422,
        fieldErrors: {
          'code': ['That code is incorrect or has expired.'],
        },
      );

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pump(const Duration(milliseconds: 100));
      expect(_repo.verifications, hasLength(1));
      // Still waiting on the server.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      _repo.verifyGate!.complete();
      await _settle(tester);

      // A wrong code leaves the person where they were: boxes empty, ready for
      // the next try, without having to tap to bring the keyboard back.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isTrue);
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('Resend after the code expired puts the keyboard back', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/code',
        extra: _codeArgs,
      );
      await tester.pump(const Duration(seconds: 125));
      expect(find.text('Code expired'), findsOneWidget);

      await _tapText(tester, 'Resend');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('Resend asks for a new code and restarts the countdown', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/code',
        extra: _codeArgs,
      );
      await tester.pump(const Duration(seconds: 45));
      expect(find.text('Code expires in 1:15'), findsOneWidget);

      await _tapText(tester, 'Resend');

      expect(_repo.requests, ['jane@gmail.com']);
      expect(find.text('A new code is on its way'), findsOneWidget);
      expect(find.text('Code expires in 2:00'), findsOneWidget);
    });

    testWidgets('Resend after the code expired unlocks the boxes again', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/code',
        extra: _codeArgs,
      );
      await tester.pump(const Duration(seconds: 125));
      expect(find.text('Code expired'), findsOneWidget);

      await _tapText(tester, 'Resend');

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(find.text('Code expired'), findsNothing);
    });

    testWidgets('Resend that is refused shows why, and keeps the countdown', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/code',
        extra: _codeArgs,
      );
      _repo.requestError = ApiException('Please wait.', statusCode: 429);
      await tester.pump(const Duration(seconds: 10));

      await _tapText(tester, 'Resend');

      expect(
        find.text('Too many attempts. Please wait a moment and try again.'),
        findsOneWidget,
      );
      // Still counting down from the original code, not restarted at 2:00.
      expect(find.textContaining('Code expires in 1:'), findsOneWidget);
    });
  });

  group('Reset Password', () {
    Future<void> fill(
      WidgetTester tester, {
      String next = 'NewPass1!',
      String? confirm,
    }) async {
      await tester.enterText(find.byType(TextFormField).at(0), next);
      await tester.enterText(find.byType(TextFormField).at(1), confirm ?? next);
      await tester.pump();
    }

    testWidgets('shows the designed screen', (tester) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/reset',
        extra: _resetArgs,
      );

      expect(find.text('Reset Password'), findsNWidgets(2)); // title + button
      expect(find.text('Create New Password'), findsOneWidget);
      expect(
        find.text('Create a new password for your account'),
        findsOneWidget,
      );
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      for (final rule in [
        'At least 8 characters',
        'At least one uppercase letter',
        'At least one number',
        'At least one special character',
      ]) {
        expect(find.text(rule), findsOneWidget, reason: rule);
      }
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('the checklist lights up as the password improves', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/reset',
        extra: _resetArgs,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      await tester.enterText(find.byType(TextFormField).at(0), 'Abcdefg1');
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(3));

      await tester.enterText(find.byType(TextFormField).at(0), 'Abcdefg1!');
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));
    });

    testWidgets('refuses a password that misses a rule', (tester) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/reset',
        extra: _resetArgs,
      );

      await fill(tester, next: 'Abcdefg1'); // no special character
      await tester.tap(find.widgetWithText(InkWell, 'Reset Password'));
      await _settle(tester);

      expect(
        find.text("Your new password doesn't meet all the requirements"),
        findsOneWidget,
      );
      expect(_repo.resets, isEmpty);
    });

    testWidgets('refuses a confirmation that does not match', (tester) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/reset',
        extra: _resetArgs,
      );

      await fill(tester, confirm: 'Different1!');
      await tester.tap(find.widgetWithText(InkWell, 'Reset Password'));
      await _settle(tester);

      expect(find.text("Passwords don't match"), findsOneWidget);
      expect(_repo.resets, isEmpty);
    });

    testWidgets('sets the password and sends the person to Sign In', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/reset',
        extra: _resetArgs,
      );

      await fill(tester);
      await tester.tap(find.widgetWithText(InkWell, 'Reset Password'));
      await _settle(tester);

      expect(_repo.resets, [
        (
          email: 'jane@gmail.com',
          token: 'reset-token-1',
          password: 'NewPass1!',
        ),
      ]);
      expect(find.text('login page'), findsOneWidget);
      expect(
        find.text('Your password was reset. Sign in with your new password.'),
        findsOneWidget,
      );
      expect(_auth.signedOut, isFalse, reason: 'nobody was signed in');
    });

    testWidgets('signs this device out too when someone was signed in', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/reset',
        extra: _resetArgs,
        user: _signedInUser,
      );

      await fill(tester);
      await tester.tap(find.widgetWithText(InkWell, 'Reset Password'));
      await _settle(tester);

      expect(_auth.signedOut, isTrue);
      expect(find.text('login page'), findsOneWidget);
    });

    testWidgets('an expired reset says to start again and stays put', (
      tester,
    ) async {
      await _pump(
        tester,
        open: '/profile/forgot-password/reset',
        extra: _resetArgs,
      );
      _repo.resetError = ApiException(
        'The given data was invalid.',
        statusCode: 422,
        fieldErrors: {
          'reset_token': ['This reset has expired. Please start again.'],
        },
      );

      await fill(tester);
      await tester.tap(find.widgetWithText(InkWell, 'Reset Password'));
      await _settle(tester);

      expect(
        find.text('This reset has expired. Please start again.'),
        findsOneWidget,
      );
      expect(find.text('login page'), findsNothing);
    });
  });
}
