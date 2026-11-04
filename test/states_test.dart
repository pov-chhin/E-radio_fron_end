import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/core/supports/tap_to_play.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/services/api_exception.dart';
import 'package:e_radio/providers/connection_provider.dart';
import 'package:e_radio/providers/notifications_pref_provider.dart';
import 'package:e_radio/providers/recent_searches_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/core/supports/require_sign_in.dart';
import 'package:e_radio/data/models/category.dart';
import 'package:e_radio/data/models/station.dart';
import 'package:e_radio/data/repositories/category_repository.dart';
import 'package:e_radio/data/repositories/media_content_repository.dart';
import 'package:e_radio/providers/station_provider.dart';
import 'package:e_radio/views/screens/explore/explore_view.dart';
import 'package:e_radio/views/widgets/explore/discover_header.dart';
import 'package:e_radio/views/widgets/explore/explore_skeleton.dart';
import 'package:e_radio/views/screens/notifications/notifications_inbox_view.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/reminder_provider.dart';
import 'package:e_radio/data/services/reminder_service.dart';
import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/data/models/user_profile.dart';
import 'package:e_radio/views/widgets/profile/auth_link_row.dart';
import 'package:e_radio/views/screens/search/search_view.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/views/widgets/shared/content_unavailable_view.dart';
import 'package:e_radio/views/widgets/shared/network_error_view.dart';
import 'package:e_radio/views/widgets/shared/state_view.dart';
import 'support/fake_connectivity.dart';
import 'support/fake_media_list.dart';

import 'support/test_fonts.dart';

const _stations = [
  Station(
    id: '1',
    name: 'Apsara FM97',
    streamUrl: 'https://example.com/1.m3u8',
    tags: ['news'],
  ),
  Station(id: '2', name: 'Morning Drive', streamUrl: 'https://example.com/2'),
];

const _categories = [
  Category(id: '1', name: 'Podcast', slug: 'podcast'),
  Category(id: '2', name: 'News', slug: 'news'),
];

/// A stations notifier whose first load is whatever [outcome] does; it counts
/// [refresh] calls rather than calling the API.
class _Stations extends StationsNotifier {
  _Stations(this.outcome);

  final Future<List<Station>> Function() outcome;
  int refreshes = 0;

  @override
  Future<List<Station>> build() => outcome();

  @override
  Future<void> refresh() async {
    refreshes++;
  }
}

class _FakePlayer extends AudioPlayerController {
  @override
  PlaybackState build() => const PlaybackState();
}

class _FakeReminders extends ReminderService {
  _FakeReminders(this.grant) : super(FlutterLocalNotificationsPlugin());

  final bool grant;

  @override
  Future<bool> requestPermission() async => grant;
}

class _FakeAuth extends AuthController {
  _FakeAuth(this.profile);

  final UserProfile? profile;

  @override
  UserProfile? build() => profile;
}

late ProviderContainer _container;
late _Stations _stationsFake;

/// Hosts [home] at "/", with the routes these screens send you to drawn as
/// plain "page /path" stubs.
Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Future<List<Station>> Function()? stations,
  bool signedIn = false,
  bool grantNotifications = true,
  Map<String, Object> prefs = const {},
  FakeConnectivitySource? connectivity,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  _stationsFake = _Stations(stations ?? () async => _stations);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (c, s) => home),
      for (final path in [
        '/explore',
        '/library',
        '/profile/login',
        '/profile/signup',
        '/profile/privacy-policy',
        '/category/:slug',
      ])
        GoRoute(
          path: path,
          builder: (c, s) => Scaffold(body: Text('page ${s.uri.path}')),
        ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          if (connectivity != null)
            connectivitySourceProvider.overrideWithValue(connectivity),
          authControllerProvider.overrideWith(
            () => _FakeAuth(
              signedIn
                  ? UserProfile(
                      id: '1',
                      firstName: 'Sok',
                      lastName: 'Dara',
                      email: 'sok@example.com',
                      joinedAt: DateTime(2026, 9, 28),
                    )
                  : null,
            ),
          ),
          stationsProvider.overrideWith(() => _stationsFake),
          categoriesProvider.overrideWith((ref) async => _categories),
          trendingMediaContentsProvider.overrideWith((ref) async => const []),
          trendingProgramMediaContentsProvider.overrideWith(
            () => FakeMediaList(const []),
          ),
          newReleaseMediaContentsProvider.overrideWith(
            () => FakeMediaList(const []),
          ),
          mediaContentsByCategoryProvider.overrideWith(
            (ref, slug) async => const [],
          ),
          mediaContentsByIdsProvider.overrideWith((ref, ids) async => const []),
          audioPlayerControllerProvider.overrideWith(_FakePlayer.new),
          reminderServiceProvider.overrideWithValue(
            _FakeReminders(grantNotifications),
          ),
        ],
      ),
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  addTearDown(_container.dispose);
  await tester.pumpAndSettle();
}

const _violet = Color(0xFF8B5CF6);

/// The painted fill behind [label]'s nearest Material.
Color? _fillOf(WidgetTester tester, String label) => tester
    .widget<Material>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first,
    )
    .color;

void main() {
  setUpAll(loadTestFonts);
  setUp(resetTapToPlay);

  group('Connection lost', () {
    testWidgets('has the title, the message and both buttons', (tester) async {
      var retried = 0;
      var offline = 0;
      await _pump(
        tester,
        Scaffold(
          body: NetworkErrorView(
            onRetry: () => retried++,
            onGoOffline: () => offline++,
          ),
        ),
      );

      expect(find.text('Connection Lost'), findsOneWidget);
      expect(
        find.text(
          'Please check your internet connection and try again to access '
          'e-Radio live stream.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Try Again'));
      await tester.tap(find.text('Go Offline'));
      expect((retried, offline), (1, 1));
    });

    testWidgets('draws the red badge and full-width buttons as designed', (
      tester,
    ) async {
      await _pump(
        tester,
        Scaffold(
          body: NetworkErrorView(onRetry: () {}, onGoOffline: () {}),
        ),
      );

      final badge = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0xFFFEE2E2),
      );
      expect(tester.getSize(badge), const Size(120, 120));

      // 40 either side of a 390 screen.
      expect(tester.getSize(find.byType(StateButton).first).width, 310);
      // Solid violet for Try Again, an outline for Go Offline.
      expect(_fillOf(tester, 'Try Again'), _violet);
      expect(_fillOf(tester, 'Go Offline'), Colors.transparent);
    });
  });

  group('Content unavailable', () {
    testWidgets('explains itself, with a header, Go Back and Report Issue', (
      tester,
    ) async {
      await _pump(tester, const ContentUnavailableView());

      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('Content Unavailable'), findsOneWidget);
      expect(
        find.text(
          'This content may have been removed or is temporarily unavailable in '
          'your region.',
        ),
        findsOneWidget,
      );
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Report Issue'), findsOneWidget);
      // The button is the design's 200 wide.
      expect(tester.getSize(find.byType(StateButton).first).width, 200);
    });

    testWidgets('Go Back goes back', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ContentUnavailableView(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Content Unavailable'), findsOneWidget);

      await tester.tap(find.text('Go Back'));
      await tester.pumpAndSettle();
      expect(find.text('Content Unavailable'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('Report Issue says it is coming soon', (tester) async {
      await _pump(tester, const ContentUnavailableView());

      await tester.tap(find.text('Report Issue'));
      await tester.pump();

      expect(find.text('Coming soon'), findsOneWidget);
    });
  });

  group('Explore before it has loaded', () {
    testWidgets('shows grey placeholders while the first load is on its way', (
      tester,
    ) async {
      final never = Completer<List<Station>>();
      await _pump(
        tester,
        const Scaffold(body: ExploreView()),
        stations: () => never.future,
      );

      expect(find.byType(ExploreSkeleton), findsOneWidget);
      // The header is a placeholder too, not the real one.
      expect(find.byType(DiscoverHeader), findsNothing);
      expect(find.text('On Air'), findsNothing);
      expect(find.text('Connection Lost'), findsNothing);
    });

    testWidgets('shows real content once it lands', (tester) async {
      await _pump(tester, const Scaffold(body: ExploreView()));

      expect(find.byType(ExploreSkeleton), findsNothing);
      expect(find.byType(DiscoverHeader), findsOneWidget);
      expect(find.text('On Air'), findsOneWidget);
    });

    testWidgets('shows Connection Lost when the server cannot be reached', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(body: ExploreView()),
        stations: () async => throw const SocketException('no route'),
      );

      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.byType(ExploreSkeleton), findsNothing);
    });

    testWidgets('shows No Internet Connection when the phone is offline', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(body: ExploreView()),
        stations: () async => throw const SocketException('no route'),
        connectivity: FakeConnectivitySource(online: false),
      );

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.text('Connection Lost'), findsNothing);
      expect(find.byType(ExploreSkeleton), findsNothing);
      // Offline it keeps looking every few seconds; stop that before the end.
      _container.dispose();
    });

    testWidgets('keeps Connection Lost for a server that is down while the '
        'phone is online', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: ExploreView()),
        stations: () async => throw const SocketException('no route'),
        connectivity: FakeConnectivitySource(online: true),
      );

      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);
    });

    testWidgets(
      'No Internet Connection: Try Again asks for the stations again',
      (tester) async {
        await _pump(
          tester,
          const Scaffold(body: ExploreView()),
          stations: () async => throw const SocketException('no route'),
          connectivity: FakeConnectivitySource(online: false),
        );

        await tester.tap(find.text('Try Again'));
        await tester.pump();

        expect(_stationsFake.refreshes, 1);
        // Offline it keeps looking every few seconds; stop that before the end.
        _container.dispose();
      },
    );

    testWidgets('asks for the stations again by itself once back online', (
      tester,
    ) async {
      final source = FakeConnectivitySource(online: false);
      await _pump(
        tester,
        const Scaffold(body: ExploreView()),
        stations: () async => throw const SocketException('no route'),
        connectivity: source,
      );
      expect(_stationsFake.refreshes, 0);

      source.online = true;
      source.connectionsChanged();
      await tester.pump();
      await tester.pump();

      expect(_stationsFake.refreshes, 1);
      await source.close();
    });

    testWidgets('Try Again asks for the stations again', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: ExploreView()),
        stations: () async => throw const SocketException('no route'),
      );

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(_stationsFake.refreshes, 1);
    });

    testWidgets('Go Offline opens the Library', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: ExploreView()),
        stations: () async => throw const SocketException('no route'),
      );

      await tester.tap(find.text('Go Offline'));
      await tester.pumpAndSettle();

      expect(find.text('page /library'), findsOneWidget);
    });

    testWidgets('an answer from the server, even an error, is not "offline"', (
      tester,
    ) async {
      await _pump(
        tester,
        const Scaffold(body: ExploreView()),
        stations: () async => throw ApiException('boom', statusCode: 500),
      );

      expect(find.text('Connection Lost'), findsNothing);
    });

    testWidgets('the placeholders are the design\'s shapes', (tester) async {
      final never = Completer<List<Station>>();
      await _pump(
        tester,
        const Scaffold(body: ExploreView()),
        stations: () => never.future,
      );

      Finder blocks(double w, double h) => find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                const Color(0xFFF1F5F9) &&
            (widget.constraints?.maxWidth == w || w == 0) &&
            widget.constraints?.maxHeight == h,
      );

      // A 180-high card, two 158 squares, a 56 thumbnail and text bars.
      expect(blocks(0, 180), findsOneWidget);
      expect(blocks(158, 158), findsNWidgets(2));
      expect(blocks(56, 56), findsOneWidget);
      expect(blocks(200, 16), findsOneWidget);
      // The header: a 40 picture, a 20 button, and a name over a greeting.
      expect(blocks(40, 40), findsOneWidget);
      expect(blocks(20, 20), findsOneWidget);
      expect(blocks(140, 20), findsOneWidget);
      expect(blocks(100, 12), findsOneWidget);
    });
  });

  group('Notifications page', () {
    testWidgets('says there is nothing yet and offers to enable them', (
      tester,
    ) async {
      await _pump(tester, const NotificationsInboxView());

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(
        find.text('Stay tuned! Your alerts and updates will appear here.'),
        findsOneWidget,
      );
      expect(find.text('Enable Notifications'), findsOneWidget);
      expect(tester.getSize(find.byType(StateButton).first).width, 220);
    });

    testWidgets('Enable Notifications turns them on once permission is given', (
      tester,
    ) async {
      await _pump(
        tester,
        const NotificationsInboxView(),
        prefs: {'notifications_enabled': false},
      );
      expect(_container.read(notificationsPrefProvider), isFalse);

      await tester.tap(find.text('Enable Notifications'));
      await tester.pump();
      await tester.pump();

      expect(_container.read(notificationsPrefProvider), isTrue);
      expect(find.text('Notifications are on'), findsOneWidget);
    });

    testWidgets('and stays off, saying why, if permission is refused', (
      tester,
    ) async {
      await _pump(
        tester,
        const NotificationsInboxView(),
        grantNotifications: false,
        prefs: {'notifications_enabled': false},
      );

      await tester.tap(find.text('Enable Notifications'));
      await tester.pump();
      await tester.pump();

      expect(_container.read(notificationsPrefProvider), isFalse);
      expect(
        find.text('Allow notifications in system settings to get reminders'),
        findsOneWidget,
      );
    });
  });

  group('Search', () {
    Future<void> enter(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pumpAndSettle();
    }

    const recents = {
      'recent_searches': ['Apsara FM97', 'Pop Music'],
    };

    testWidgets('opens on the categories to browse, not a list of stations', (
      tester,
    ) async {
      await _pump(tester, const Scaffold(body: SearchView()));

      expect(find.text('Browse Categories'), findsOneWidget);
      for (final name in [
        'Radio',
        'Podcast',
        'News',
        'Songs',
        'Ambient Music',
        'Health',
        'Economy',
        'Education',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('Apsara FM97'), findsNothing);
      // Nothing searched yet, nothing trending to offer.
      expect(find.text('Recent Searches'), findsNothing);
      expect(find.text('Trending Searches'), findsNothing);
    });

    testWidgets('a category tile goes to that category', (tester) async {
      await _pump(tester, const Scaffold(body: SearchView()));

      await tester.tap(find.text('News'));
      await tester.pumpAndSettle();

      expect(find.text('page /category/news'), findsOneWidget);
    });

    testWidgets('lists the recent searches as chips, which clear one by one', (
      tester,
    ) async {
      await _pump(tester, const Scaffold(body: SearchView()), prefs: recents);

      expect(find.text('Recent Searches'), findsOneWidget);
      expect(find.text('Apsara FM97'), findsOneWidget);
      expect(find.text('Pop Music'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove Pop Music'));
      await tester.pumpAndSettle();
      expect(find.text('Pop Music'), findsNothing);
      expect(_container.read(recentSearchesProvider), ['Apsara FM97']);

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();
      expect(find.text('Recent Searches'), findsNothing);
      expect(_container.read(recentSearchesProvider), isEmpty);
    });

    testWidgets('a tap on a recent search searches for it, grouped', (
      tester,
    ) async {
      await _pump(tester, const Scaffold(body: SearchView()), prefs: recents);

      await tester.tap(find.text('Apsara FM97'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Apsara FM97',
      );
      expect(find.text('Radio Stations'), findsOneWidget);
      expect(find.text('Morning Drive'), findsNothing);
    });

    testWidgets(
      'with the bar in focus and nothing typed, shows a list of recent '
      'searches instead of the categories',
      (tester) async {
        await _pump(tester, const Scaffold(body: SearchView()), prefs: recents);

        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();

        expect(find.text('Browse Categories'), findsNothing);
        expect(find.text('Recent Searches'), findsNothing);
        expect(find.text('Apsara FM97'), findsOneWidget);
        expect(find.text('Pop Music'), findsOneWidget);
        // The arrow backs out of it.
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Browse Categories'), findsOneWidget);
      },
    );

    testWidgets('the ✕ on a focused, empty bar closes the search', (
      tester,
    ) async {
      await _pump(tester, const Scaffold(body: SearchView()), prefs: recents);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      // The design drops the hint once the bar is in use.
      expect(find.text('Search radio, podcasts, songs...'), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Browse Categories'), findsOneWidget);
      expect(find.text('Search radio, podcasts, songs...'), findsOneWidget);
    });

    testWidgets('typing lists what matches as one list, without headings', (
      tester,
    ) async {
      await _pump(tester, const Scaffold(body: SearchView()));

      await enter(tester, 'apsara');

      expect(find.text('Apsara FM97'), findsOneWidget);
      expect(find.text('Morning Drive'), findsNothing);
      expect(find.text('Radio Stations'), findsNothing);
    });

    testWidgets('sending it in groups the matches and remembers the words', (
      tester,
    ) async {
      await _pump(tester, const Scaffold(body: SearchView()));

      await enter(tester, ' apsara ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Radio Stations'), findsOneWidget);
      expect(find.text('Apsara FM97'), findsOneWidget);
      expect(_container.read(recentSearchesProvider), ['apsara']);
    });

    testWidgets(
      'suggests recent searches that contain the words, and ↖ drops one into '
      'the bar',
      (tester) async {
        await _pump(
          tester,
          const Scaffold(body: SearchView()),
          prefs: {
            'recent_searches': ['Apsara night show', 'Pop Music'],
          },
        );

        await enter(tester, 'apsara');

        expect(find.text('Apsara night show'), findsOneWidget);
        expect(find.text('Pop Music'), findsNothing);

        await tester.tap(find.byTooltip('Search for Apsara night show'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Apsara night show',
        );
        // Filling the bar is not sending it in: nothing new is remembered.
        expect(_container.read(recentSearchesProvider), [
          'Apsara night show',
          'Pop Music',
        ]);
      },
    );

    testWidgets('says so, and offers the categories to browse', (tester) async {
      await _pump(tester, const Scaffold(body: SearchView()));

      await enter(tester, 'samraam');

      expect(find.text('No results found'), findsOneWidget);
      expect(
        find.text('Try another keyword or explore popular categories below.'),
        findsOneWidget,
      );
      expect(find.text('Podcast'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);

      await tester.tap(find.text('News'));
      await tester.pumpAndSettle();
      expect(find.text('page /category/news'), findsOneWidget);
    });

    testWidgets('the bar is a 42-high pill, white with a hairline', (
      tester,
    ) async {
      await _pump(tester, const Scaffold(body: SearchView()));

      final bar = find.ancestor(
        of: find.byType(TextField),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(bar.first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(80));
      expect(tester.getSize(bar.first).height, 42);
    });

    testWidgets('a ✕ appears with text and clears it', (tester) async {
      await _pump(tester, const Scaffold(body: SearchView()));
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      await enter(tester, 'samraam');
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      // The magnifier becomes a back arrow.
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('No results found'), findsNothing);
      expect(find.text('Browse Categories'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('the back arrow backs out of the search', (tester) async {
      await _pump(tester, const Scaffold(body: SearchView()));

      await enter(tester, 'samraam');
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Browse Categories'), findsOneWidget);
    });
  });

  group('The sign-in sheet', () {
    var ran = 0;

    Widget trigger() => Consumer(
      builder: (context, ref, _) => Scaffold(
        body: TextButton(
          onPressed: () => requireSignIn(context, ref, () => ran++),
          child: const Text('favorite it'),
        ),
      ),
    );

    setUp(() => ran = 0);

    testWidgets('slides up for a guest, and does not run the action', (
      tester,
    ) async {
      await _pump(tester, trigger());

      await tester.tap(find.text('favorite it'));
      await tester.pumpAndSettle();

      expect(ran, 0);
      expect(find.text('Sign in'), findsNWidgets(2)); // title + link
      expect(find.text('Log in to save your favorites'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('OR'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Have an account? '), findsOneWidget);
      expect(
        find.textContaining(
          'By continuing, you agree to our',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('does nothing but the action for someone signed in', (
      tester,
    ) async {
      await _pump(tester, trigger(), signedIn: true);

      await tester.tap(find.text('favorite it'));
      await tester.pumpAndSettle();

      expect(ran, 1);
      expect(find.text('Log in to save your favorites'), findsNothing);
    });

    testWidgets('has 56-high buttons and rounded top corners', (tester) async {
      await _pump(tester, trigger());
      await tester.tap(find.text('favorite it'));
      await tester.pumpAndSettle();

      double heightOf(String label) => tester
          .getSize(
            find
                .ancestor(of: find.text(label), matching: find.byType(Ink))
                .first,
          )
          .height;

      expect(heightOf('Continue with Google'), 56);
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Create Account'),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .height,
        56,
      );

      final sheet = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Log in to save your favorites'),
              matching: find.byType(Container),
            )
            .last,
      );
      expect(
        (sheet.decoration! as BoxDecoration).borderRadius,
        const BorderRadius.vertical(top: Radius.circular(30)),
      );
    });

    testWidgets('Create Account closes it and opens sign-up', (tester) async {
      await _pump(tester, trigger());
      await tester.tap(find.text('favorite it'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('page /profile/signup'), findsOneWidget);
    });

    testWidgets('the Sign in link closes it and opens the login page', (
      tester,
    ) async {
      await _pump(tester, trigger());
      await tester.tap(find.text('favorite it'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AuthLinkRow),
          matching: find.text('Sign in'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('page /profile/login'), findsOneWidget);
    });

    testWidgets('the ✕ closes it', (tester) async {
      await _pump(tester, trigger());
      await tester.tap(find.text('favorite it'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Log in to save your favorites'), findsNothing);
    });

    testWidgets('Continue with Google says it is coming soon', (tester) async {
      await _pump(tester, trigger());
      await tester.tap(find.text('favorite it'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(find.text('Coming soon'), findsOneWidget);
    });
  });
}
