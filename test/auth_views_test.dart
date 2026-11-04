import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/views/screens/profile/login_view.dart';
import 'package:e_radio/data/models/user_profile.dart';
import 'package:e_radio/views/screens/profile/signup_view.dart';
import 'package:e_radio/views/widgets/shared/google_g_logo.dart';
import 'package:e_radio/views/widgets/shared/see_all_header.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';

import 'support/test_fonts.dart';

/// Records what the screens send instead of calling the API.
class _FakeAuth extends AuthController {
  Map<String, String>? signUpArgs;
  Map<String, String>? signInArgs;

  @override
  UserProfile? build() => null;

  @override
  Future<void> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    signUpArgs = {
      'first': firstName,
      'last': lastName,
      'email': email,
      'password': password,
    };
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInArgs = {'email': email, 'password': password};
  }
}

late _FakeAuth _auth;

/// Opens [path] on top of a "home" page, the way Profile pushes these screens.
Future<GoRouter> _pumpAt(WidgetTester tester, String path) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  _auth = _FakeAuth();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/profile/login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/profile/signup',
        builder: (context, state) => const SignUpView(),
      ),
      GoRoute(
        path: '/profile/privacy-policy',
        builder: (context, state) =>
            const Scaffold(body: Text('privacy policy page')),
      ),
      // Stand-in for the forgotten-password flow, showing what it was handed.
      GoRoute(
        path: '/profile/forgot-password',
        builder: (context, state) =>
            Scaffold(body: Text('forgot page: ${state.extra}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => _auth)],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  router.push(path);
  await tester.pumpAndSettle();
  return router;
}

Finder _field(int index) => find.byType(TextFormField).at(index);

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(InkWell, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  group('Create Account', () {
    testWidgets('shows the designed form', (tester) async {
      await _pumpAt(tester, '/profile/signup');

      expect(find.text('Create account'), findsNWidgets(2)); // heading + button
      expect(find.text('Enter your credentials to continue'), findsOneWidget);
      for (final label in [
        'First name',
        'Last name',
        'Email address',
        'Password',
        'Confirm password',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Enter your first name'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.textContaining('Have an account?'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets(
      'asks for every field when submitted empty, without calling the API',
      (tester) async {
        await _pumpAt(tester, '/profile/signup');

        await _tapButton(tester, 'Create account');

        expect(find.text('This field is required'), findsNWidgets(2));
        expect(find.text('Enter a valid email address'), findsOneWidget);
        expect(find.text('Use at least 8 characters'), findsOneWidget);
        expect(_auth.signUpArgs, isNull);
      },
    );

    testWidgets('rejects a confirmation that does not match', (tester) async {
      await _pumpAt(tester, '/profile/signup');

      await tester.enterText(_field(0), 'Sok');
      await tester.enterText(_field(1), 'Dara');
      await tester.enterText(_field(2), 'sok@example.com');
      await tester.enterText(_field(3), 'password123');
      await tester.enterText(_field(4), 'password124');
      await _tapButton(tester, 'Create account');

      expect(find.text("Passwords don't match"), findsOneWidget);
      expect(_auth.signUpArgs, isNull);
    });

    testWidgets('sends the trimmed details once the form is valid', (
      tester,
    ) async {
      await _pumpAt(tester, '/profile/signup');

      await tester.enterText(_field(0), '  Sok ');
      await tester.enterText(_field(1), 'Dara');
      await tester.enterText(_field(2), ' sok@example.com ');
      await tester.enterText(_field(3), 'password123');
      await tester.enterText(_field(4), 'password123');
      await _tapButton(tester, 'Create account');

      expect(_auth.signUpArgs, {
        'first': 'Sok',
        'last': 'Dara',
        'email': 'sok@example.com',
        'password': 'password123',
      });
      // Signed up → the screen closes, back to where it was opened from.
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('the eye shows and hides the password', (tester) async {
      await _pumpAt(tester, '/profile/signup');
      bool obscured() => tester
          .widget<EditableText>(find.byType(EditableText).at(3))
          .obscureText;

      expect(obscured(), isTrue);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
      await tester.pump();

      expect(obscured(), isFalse);
    });

    testWidgets('"Sign in" swaps to the Sign In screen', (tester) async {
      await _pumpAt(tester, '/profile/signup');

      // Below the fold since the Google button went in above it.
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('Sign In', () {
    testWidgets('shows the designed form and terms strip', (tester) async {
      await _pumpAt(tester, '/profile/login');

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.textContaining("Don't have an account?"), findsOneWidget);
      expect(find.text('Sign up'), findsOneWidget);
      expect(
        find.textContaining(
          'By continuing, you agree to our',
          findRichText: true,
        ),
        findsOneWidget,
      );
      // The updated design has the Google button, under Login.
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('has Continue with Google under Login, above the sign-up link', (
      tester,
    ) async {
      await _pumpAt(tester, '/profile/login');

      final login = tester.getTopLeft(find.widgetWithText(InkWell, 'Login')).dy;
      final google = find.widgetWithText(InkWell, 'Continue with Google');
      final signUp = tester.getTopLeft(find.textContaining("Don't have")).dy;

      expect(google, findsOneWidget);
      expect(tester.getTopLeft(google).dy, greaterThan(login));
      expect(tester.getTopLeft(google).dy, lessThan(signUp));
      // The same full-width pill as Login, with the Google mark on a white disc.
      expect(
        tester.getSize(google),
        tester.getSize(find.widgetWithText(InkWell, 'Login')),
      );
      expect(
        find.descendant(of: google, matching: find.byType(GoogleBadge)),
        findsOneWidget,
      );
    });

    testWidgets('the password\'s eye is at the left of the field', (
      tester,
    ) async {
      await _pumpAt(tester, '/profile/login');

      final field = tester.getRect(_field(1));
      final eye = tester.getCenter(find.byIcon(Icons.visibility_off_outlined));
      // Inside the field, near its left edge, before the text.
      expect(field.contains(eye), isTrue);
      expect(eye.dx - field.left, lessThan(48));
      final text = tester.getTopLeft(find.byType(EditableText).at(1)).dx;
      expect(eye.dx, lessThan(text));
    });

    testWidgets('the left eye shows and hides the password', (tester) async {
      await _pumpAt(tester, '/profile/login');
      bool obscured() => tester
          .widget<EditableText>(find.byType(EditableText).at(1))
          .obscureText;

      expect(obscured(), isTrue);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(obscured(), isFalse);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('Create Account keeps its eye at the right', (tester) async {
      await _pumpAt(tester, '/profile/signup');

      final password = find.byType(TextFormField).at(3);
      final field = tester.getRect(password);
      final eye = tester.getCenter(
        find.byIcon(Icons.visibility_off_outlined).first,
      );
      expect(field.right - eye.dx, lessThan(48));
    });

    testWidgets('the back arrow returns to the page that opened it', (
      tester,
    ) async {
      await _pumpAt(tester, '/profile/login');

      await tester.tap(
        find.descendant(
          of: find.byType(SeeAllHeader),
          matching: find.byType(InkResponse),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
    });

    testWidgets('validates before calling the API', (tester) async {
      await _pumpAt(tester, '/profile/login');

      await _tapButton(tester, 'Login');

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('This field is required'), findsOneWidget);
      expect(_auth.signInArgs, isNull);
    });

    testWidgets('signs in with the trimmed email', (tester) async {
      await _pumpAt(tester, '/profile/login');

      await tester.enterText(_field(0), ' sok@example.com ');
      await tester.enterText(_field(1), 'secret');
      await _tapButton(tester, 'Login');

      expect(_auth.signInArgs, {
        'email': 'sok@example.com',
        'password': 'secret',
      });
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('"Forgot password?" starts the reset flow', (tester) async {
      await _pumpAt(tester, '/profile/login');

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('forgot page: null'), findsOneWidget);
    });

    testWidgets('"Forgot password?" carries over an email already typed', (
      tester,
    ) async {
      await _pumpAt(tester, '/profile/login');

      await tester.enterText(_field(0), ' sok@example.com ');
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(find.text('forgot page: sok@example.com'), findsOneWidget);
    });

    testWidgets('the footer Privacy Policy link opens the policy', (
      tester,
    ) async {
      await _pumpAt(tester, '/profile/login');

      await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.text('privacy policy page'), findsOneWidget);
    });

    testWidgets('the footer Terms link says Coming soon', (tester) async {
      await _pumpAt(tester, '/profile/login');

      await tester.tapOnText(find.textRange.ofSubstring('Terms'));
      await tester.pump();

      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('"Sign up" swaps to the Create Account screen', (tester) async {
      await _pumpAt(tester, '/profile/login');

      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm password'), findsOneWidget);
    });
  });
}
