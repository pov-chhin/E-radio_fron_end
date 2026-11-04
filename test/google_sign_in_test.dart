import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/core/supports/require_sign_in.dart';
import 'package:e_radio/data/services/api_client.dart';
import 'package:e_radio/data/services/api_exception.dart';
import 'package:e_radio/data/services/google_sign_in_service.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/screens/profile/login_view.dart';
import 'package:e_radio/views/screens/welcome/welcome_view.dart';
import 'package:e_radio/views/widgets/profile/google_signin_button.dart';

import 'support/test_fonts.dart';

/// Google's side, without Google: [token] is what the account picker hands
/// back (null = the person closed it), [error] what it throws instead.
class _FakeGoogle extends GoogleSignInService {
  _FakeGoogle({this.available = true, this.token = 'google-id-token'});

  final bool available;
  final String? token;
  Object? error;
  var signIns = 0;
  var signOuts = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<String?> signIn() async {
    signIns++;
    if (error != null) throw error!;
    return token;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

/// The API's side: what `POST /auth/google` is sent, and the session it gives.
class _FakeApi extends ApiClient {
  final posts = <(String, Map<String, dynamic>)>[];
  Object? failWith;

  @override
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    posts.add((path, body));
    if (failWith != null) throw failWith!;
    if (path == '/logout') return null;
    return {
      'user': {
        'id': '7',
        'first_name': 'Sophea',
        'last_name': 'Chan',
        'email': 'sophea@gmail.com',
        'joined_at': '2026-10-01T00:00:00.000Z',
        'avatar_url': 'https://lh3.googleusercontent.com/a/sophea',
      },
      'token': 'sanctum-token',
    };
  }
}

late _FakeGoogle _google;
late _FakeApi _api;
late SharedPreferences _prefs;
late ProviderContainer _container;

Future<void> _setUp({
  bool available = true,
  String? token = 'google-id-token',
}) async {
  SharedPreferences.setMockInitialValues({});
  _prefs = await SharedPreferences.getInstance();
  _google = _FakeGoogle(available: available, token: token);
  _api = _FakeApi();
}

List<Override> _overrides() => [
  sharedPreferencesProvider.overrideWithValue(_prefs),
  apiClientProvider.overrideWithValue(_api),
  googleSignInServiceProvider.overrideWithValue(_google),
];

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Widget _routerApp(GoRouter router) => MaterialApp.router(
  routerConfig: router,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
);

Future<void> _pumpApp(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(overrides: _overrides(), child: app));
  await tester.pumpAndSettle();
  _container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  );
}

const _failedMessage = "Couldn't sign in with Google. Please try again.";
const _cancelledMessage = "Google sign-in didn't finish. Please try again.";
const _refusedMessage =
    "Google sign-in didn't finish. Google said: [16] Account reauth failed.";
const _closedEarlyMessage =
    'Google sign-in closed straight away. Make sure a Google account is added '
    'to this device, then try again.';

void main() {
  setUpAll(loadTestFonts);

  group('the text Google gives with a "cancelled"', () {
    test('is a plain cancel when it only says the person closed the sheet', () {
      expect(isPlainCancel(null), true);
      expect(isPlainCancel(''), true);
      expect(isPlainCancel('activity is cancelled by the user.'), true);
      expect(isPlainCancel('Activity is canceled by the user'), true);
      // What Google Play services says when its own Cancel is tapped.
      expect(isPlainCancel('[16] Cancelled by user.'), true);
    });

    test('is a refusal when it says anything else', () {
      expect(isPlainCancel('[16] Account reauth failed.'), false);
      expect(
        isPlainCancel('[28444] Developer console is not set up correctly.'),
        false,
      );
    });
  });

  group('a "cancelled" from Google', () {
    test('that came at once is not a choice; one that took a while is', () {
      expect(closedTooSoonToBeAChoice(const Duration(milliseconds: 600)), true);
      expect(closedTooSoonToBeAChoice(Duration.zero), true);
      expect(
        closedTooSoonToBeAChoice(const Duration(milliseconds: 1500)),
        false,
      );
      expect(closedTooSoonToBeAChoice(const Duration(seconds: 6)), false);
    });
  });

  group('AuthController.signInWithGoogle', () {
    ProviderContainer container() {
      final c = ProviderContainer(overrides: _overrides());
      addTearDown(c.dispose);
      return c;
    }

    test('swaps Google\'s ID token for a session', () async {
      await _setUp();
      final c = container();

      final signedIn = await c
          .read(authControllerProvider.notifier)
          .signInWithGoogle();

      expect(signedIn, isTrue);
      expect(_api.posts, hasLength(1));
      expect(_api.posts.single.$1, '/auth/google');
      expect(_api.posts.single.$2, {'id_token': 'google-id-token'});
      expect(c.read(authControllerProvider)?.email, 'sophea@gmail.com');
      expect(
        c.read(authControllerProvider)?.avatarUrl,
        'https://lh3.googleusercontent.com/a/sophea',
      );
      expect(_prefs.getString('auth_token'), 'sanctum-token');
    });

    test('does nothing when the person closes the account picker', () async {
      await _setUp(token: null);
      final c = container();

      final signedIn = await c
          .read(authControllerProvider.notifier)
          .signInWithGoogle();

      expect(signedIn, isFalse);
      expect(_api.posts, isEmpty);
      expect(c.read(authControllerProvider), isNull);
    });

    test('leaves them signed out when the API refuses the token', () async {
      await _setUp();
      _api.failWith = ApiException(
        'Google sign-in could not be verified.',
        statusCode: 422,
      );
      final c = container();

      await expectLater(
        c.read(authControllerProvider.notifier).signInWithGoogle(),
        throwsA(isA<ApiException>()),
      );

      expect(c.read(authControllerProvider), isNull);
      expect(_prefs.getString('auth_token'), isNull);
    });

    test('signing out of the app signs out of Google too', () async {
      await _setUp();
      final c = container();
      await c.read(authControllerProvider.notifier).signInWithGoogle();

      await c.read(authControllerProvider.notifier).signOut();

      expect(_google.signOuts, 1);
      expect(c.read(authControllerProvider), isNull);
    });
  });

  group('Welcome', () {
    Future<void> pumpWelcome(WidgetTester tester) => _pumpApp(
      tester,
      _routerApp(
        GoRouter(
          initialLocation: '/welcome',
          routes: [
            GoRoute(path: '/welcome', builder: (_, _) => const WelcomeView()),
            GoRoute(
              path: '/explore',
              builder: (_, _) => const Scaffold(body: Text('explore page')),
            ),
          ],
        ),
      ),
    );

    testWidgets('Continue with Google signs in and carries on to Explore', (
      tester,
    ) async {
      await _setUp();
      await pumpWelcome(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(_api.posts.single.$1, '/auth/google');
      expect(find.text('explore page'), findsOneWidget);
    });

    testWidgets('stays put and says it did not finish if the picker ends '
        'without an account', (tester) async {
      await _setUp(token: null);
      await pumpWelcome(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text(_cancelledMessage), findsOneWidget);
      expect(find.text(_failedMessage), findsNothing);
      expect(_api.posts, isEmpty);
    });

    testWidgets('says so when Google or the API lets it down', (tester) async {
      await _setUp();
      _api.failWith = ApiException('nope', statusCode: 503);
      await pumpWelcome(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text(_failedMessage), findsOneWidget);
    });

    testWidgets('says what to check when the sheet closes by itself', (
      tester,
    ) async {
      await _setUp();
      _google.error = const GoogleSignInClosedEarly();
      await pumpWelcome(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text(_closedEarlyMessage), findsOneWidget);
      expect(find.text(_failedMessage), findsNothing);
      expect(_api.posts, isEmpty);
    });

    testWidgets('shows what Google said when it turns the app down', (
      tester,
    ) async {
      await _setUp();
      _google.error = const GoogleSignInRefused('[16] Account reauth failed.');
      await pumpWelcome(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text(_refusedMessage), findsOneWidget);
      expect(find.text(_failedMessage), findsNothing);
      expect(_api.posts, isEmpty);
    });

    testWidgets('says so when Google itself throws', (tester) async {
      await _setUp();
      _google.error = StateError('no credentials');
      await pumpWelcome(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();

      expect(find.text(_failedMessage), findsOneWidget);
      expect(_api.posts, isEmpty);
    });

    testWidgets('says Coming soon while there is no Google client ID', (
      tester,
    ) async {
      await _setUp(available: false);
      await pumpWelcome(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(find.text('Coming soon'), findsOneWidget);
      expect(_google.signIns, 0);
      expect(_api.posts, isEmpty);
    });
  });

  group('The sign-in sheet', () {
    Widget trigger() => Consumer(
      builder: (context, ref, _) => Scaffold(
        body: TextButton(
          onPressed: () => requireSignIn(context, ref, () {}),
          child: const Text('favorite it'),
        ),
      ),
    );

    Future<void> openSheet(WidgetTester tester) async {
      await _pumpApp(tester, _app(trigger()));
      await tester.tap(find.text('favorite it'));
      await tester.pumpAndSettle();
      expect(find.text('Log in to save your favorites'), findsOneWidget);
    }

    testWidgets('Continue with Google signs in and closes it', (tester) async {
      await _setUp();
      await openSheet(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Log in to save your favorites'), findsNothing);
      expect(
        _container.read(authControllerProvider)?.email,
        'sophea@gmail.com',
      );
    });

    testWidgets('stays open if the account picker is closed', (tester) async {
      await _setUp(token: null);
      await openSheet(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Log in to save your favorites'), findsOneWidget);
      expect(_container.read(authControllerProvider), isNull);
    });

    testWidgets('closes when the sheet shut by itself, saying what to check', (
      tester,
    ) async {
      await _setUp();
      _google.error = const GoogleSignInClosedEarly();
      await openSheet(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Log in to save your favorites'), findsNothing);
      expect(find.text(_closedEarlyMessage), findsOneWidget);
    });

    testWidgets('closes when Google turned the app down, saying what it said', (
      tester,
    ) async {
      await _setUp();
      _google.error = const GoogleSignInRefused('[16] Account reauth failed.');
      await openSheet(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Log in to save your favorites'), findsNothing);
      expect(find.text(_refusedMessage), findsOneWidget);
    });

    testWidgets('closes on a failure, so its message is not left behind it', (
      tester,
    ) async {
      await _setUp();
      _api.failWith = ApiException('nope', statusCode: 422);
      await openSheet(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Log in to save your favorites'), findsNothing);
      expect(find.text(_failedMessage), findsOneWidget);
    });
  });

  group('The sign-in page\'s button', () {
    Future<void> pumpSignIn(WidgetTester tester) async {
      await _pumpApp(
        tester,
        _routerApp(
          GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                  body: Column(
                    children: [
                      const Text('home page'),
                      TextButton(
                        onPressed: () => context.push('/login'),
                        child: const Text('open sign-in'),
                      ),
                    ],
                  ),
                ),
              ),
              GoRoute(path: '/login', builder: (_, _) => const LoginView()),
            ],
          ),
        ),
      );
      await tester.tap(find.text('open sign-in'));
      await tester.pumpAndSettle();
    }

    testWidgets('signs in and closes the page', (tester) async {
      await _setUp();
      await pumpSignIn(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('home page'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      expect(
        _container.read(authControllerProvider)?.email,
        'sophea@gmail.com',
      );
    });

    testWidgets('keeps the page, saying it did not finish, if the picker ends '
        'without an account', (tester) async {
      await _setUp(token: null);
      await pumpSignIn(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('home page'), findsNothing);
      expect(find.text(_cancelledMessage), findsOneWidget);
    });

    testWidgets('says Coming soon while there is no Google client ID', (
      tester,
    ) async {
      await _setUp(available: false);
      await pumpSignIn(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(_google.signIns, 0);
    });
  });

  group('The sign-up page\'s button', () {
    Future<void> pumpSignUp(WidgetTester tester) async {
      await _pumpApp(
        tester,
        _routerApp(
          GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                  body: Column(
                    children: [
                      const Text('home page'),
                      TextButton(
                        onPressed: () => context.push('/signup'),
                        child: const Text('open sign-up'),
                      ),
                    ],
                  ),
                ),
              ),
              GoRoute(
                path: '/signup',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: GoogleSignInButton())),
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('open sign-up'));
      await tester.pumpAndSettle();
    }

    testWidgets('signs in and closes the page', (tester) async {
      await _setUp();
      await pumpSignUp(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('home page'), findsOneWidget);
      expect(
        _container.read(authControllerProvider)?.email,
        'sophea@gmail.com',
      );
    });

    testWidgets('keeps the page, saying it did not finish, if the picker ends '
        'without an account', (tester) async {
      await _setUp(token: null);
      await pumpSignUp(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('home page'), findsNothing);
      expect(find.text(_cancelledMessage), findsOneWidget);
    });
  });
}
