import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/providers/has_seen_onboarding_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/screens/onboarding/onboarding_view.dart';
import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/data/models/user_profile.dart';
import 'package:e_radio/views/screens/welcome/welcome_view.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';

import 'support/test_fonts.dart';

/// Lets a test complete a sign-in without the API.
class _FakeAuth extends AuthController {
  @override
  UserProfile? build() => null;

  void completeSignIn() => state = UserProfile(
    id: '1',
    firstName: 'Sok',
    lastName: 'Dara',
    email: 'sok@example.com',
    joinedAt: DateTime(2026, 9, 28),
  );
}

late _FakeAuth _auth;
late GoRouter _router;
late SharedPreferences _prefs;

/// The real app's routes are stubbed with labelled pages so a test can see
/// where a tap ended up.
Future<void> _pump(
  WidgetTester tester, {
  required String initialLocation,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  _prefs = await SharedPreferences.getInstance();
  _auth = _FakeAuth();
  _router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingView(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeView(),
      ),
      GoRoute(
        path: '/explore',
        builder: (context, state) => const Scaffold(body: Text('explore page')),
      ),
      GoRoute(
        path: '/profile/signup',
        builder: (context, state) => const Scaffold(body: Text('signup page')),
      ),
      GoRoute(
        path: '/profile/login',
        builder: (context, state) => const Scaffold(body: Text('login page')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        authControllerProvider.overrideWith(() => _auth),
      ],
      child: MaterialApp.router(
        routerConfig: _router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  group('Welcome', () {
    testWidgets('shows the designed screen', (tester) async {
      await _pump(tester, initialLocation: '/welcome');

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Enter your credentials to continue'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('OR'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.textContaining('Have an account?'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(
        find.textContaining(
          'By continuing, you agree to our',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('Skip goes straight to Explore', (tester) async {
      await _pump(tester, initialLocation: '/welcome');

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('explore page'), findsOneWidget);
    });

    testWidgets('Create Account opens sign-up, and back returns here', (
      tester,
    ) async {
      await _pump(tester, initialLocation: '/welcome');

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(find.text('signup page'), findsOneWidget);

      _router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('"Sign in" opens the sign-in screen', (tester) async {
      await _pump(tester, initialLocation: '/welcome');

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('login page'), findsOneWidget);
    });

    testWidgets(
      'Continue with Google says Coming soon — there is no Google sign-in yet',
      (tester) async {
        await _pump(tester, initialLocation: '/welcome');

        await tester.tap(find.text('Continue with Google'));
        await tester.pump();

        expect(find.text('Coming soon'), findsOneWidget);
      },
    );

    testWidgets('finishing a sign-in from here carries on to Explore', (
      tester,
    ) async {
      await _pump(tester, initialLocation: '/welcome');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('login page'), findsOneWidget);

      _auth.completeSignIn();
      await tester.pumpAndSettle();

      expect(find.text('explore page'), findsOneWidget);
    });
  });

  group('Leaving onboarding', () {
    Future<void> toLastPage(WidgetTester tester) async {
      await tester.pump(
        const Duration(milliseconds: 1900),
      ); // splash → Discover
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(PageView),
        const Offset(-300, 0),
      ); // → Pick Your Favorites
      await tester.pumpAndSettle();
      await tester.tap(find.text('Music')); // Continue comes in with a pick
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue')); // → One Tap to Play
      await tester.pumpAndSettle();
    }

    testWidgets(
      '"Let\'s Go!" offers the optional sign-up and marks the intro seen',
      (tester) async {
        await _pump(tester, initialLocation: '/onboarding');
        await toLastPage(tester);

        await tester.tap(find.text("Let's Go!"));
        await tester.pumpAndSettle();

        expect(find.text('Welcome'), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(WelcomeView)),
        );
        expect(container.read(hasSeenOnboardingProvider), isTrue);
      },
    );

    testWidgets(
      'Skip on the intro goes straight to Explore and marks it seen',
      (tester) async {
        await _pump(tester, initialLocation: '/onboarding');
        await tester.pump(const Duration(milliseconds: 1900));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        expect(find.text('explore page'), findsOneWidget);
        expect(_prefs.getBool('has_seen_onboarding'), isTrue);
      },
    );
  });
}
