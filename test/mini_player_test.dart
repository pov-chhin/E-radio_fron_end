import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/views/themes/app_colors.dart';
import 'package:e_radio/data/models/station.dart';
import 'package:e_radio/data/models/user_profile.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/views/widgets/player/mini_player.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/views/widgets/shared/artwork_avatar.dart';
import 'package:e_radio/views/widgets/shared/playing_indicator.dart';

/// Skips the real controller's AudioPlayer (needs a platform channel) — these
/// tests only look at what the bar renders for a given PlaybackState.
class _FakePlayerController extends AudioPlayerController {
  _FakePlayerController(this._initial, {Duration? position, Duration? duration})
    : _position = position,
      _duration = duration;

  final PlaybackState _initial;
  final Duration? _position;
  final Duration? _duration;

  @override
  PlaybackState build() => _initial;

  // The real ones come from the audio plugin.
  @override
  Stream<Duration> get positionStream =>
      Stream.value(_position ?? Duration.zero);

  @override
  Stream<Duration?> get durationStream => Stream.value(_duration);
}

/// Where favorites are kept; reset before every test.
late SharedPreferences _prefs;

class _SignedIn extends AuthController {
  @override
  UserProfile? build() => UserProfile(
    id: '1',
    firstName: 'Pov',
    lastName: 'Chhin',
    email: 'pov@example.com',
    joinedAt: DateTime(2026),
  );
}

Widget _app(
  PlaybackState initial, {
  Duration? position,
  Duration? duration,
  bool signedIn = false,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: SizedBox.expand(),
          bottomNavigationBar: MiniPlayer(),
        ),
      ),
      GoRoute(
        path: '/play-list',
        builder: (context, state) =>
            const Scaffold(body: Text('playlist page')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_prefs),
      if (signedIn) authControllerProvider.overrideWith(_SignedIn.new),
      audioPlayerControllerProvider.overrideWith(
        () => _FakePlayerController(
          initial,
          position: position,
          duration: duration,
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

PlaybackState _playing(NowPlayingItem item) =>
    PlaybackState(item: item, status: PlaybackStatus.playing);

const _station = Station(
  id: '1',
  name: 'Apsara FM97',
  streamUrl: 'http://example.com/live.m3u8',
  tags: ['News'],
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('renders nothing until something is loaded', (tester) async {
    await tester.pumpWidget(_app(const PlaybackState()));

    expect(find.byType(Dismissible), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
  });

  testWidgets('shows a live station with its tag, "Live" and a pause button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_playing(NowPlayingItem.fromStation(_station))),
    );

    expect(find.text('Apsara FM97'), findsOneWidget);
    expect(find.text('News • Live'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('a live station without a tag just says "Live"', (tester) async {
    const untagged = Station(
      id: '2',
      name: 'FM 97',
      streamUrl: 'http://example.com/live.m3u8',
    );
    await tester.pumpWidget(
      _app(_playing(NowPlayingItem.fromStation(untagged))),
    );

    expect(find.text('Live'), findsOneWidget);
  });

  testWidgets('shows a play button while paused', (tester) async {
    final item = NowPlayingItem.fromStation(_station);
    await tester.pumpWidget(
      _app(PlaybackState(item: item, status: PlaybackStatus.paused)),
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  group('the + button', () {
    final red = find.byKey(const Key('favoriteRed'));
    final plus = find.byIcon(Icons.add_circle_outline_rounded);

    testWidgets('is a white outline, named Add to favorites, until it is one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_playing(NowPlayingItem.fromStation(_station))),
      );

      expect(plus, findsOneWidget);
      expect(tester.widget<Icon>(plus).color, isNull); // the bar's white
      expect(red, findsNothing);
      expect(find.byTooltip('Add to favorites'), findsOneWidget);
    });

    testWidgets('turns red, rimmed in white, once it is a favorite', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'favorite_station_ids': ['station:1'],
      });
      _prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        _app(_playing(NowPlayingItem.fromStation(_station))),
      );

      expect(red, findsOneWidget);
      expect(plus, findsNothing);
      final disc = tester.widget<Container>(red).decoration as BoxDecoration;
      expect(disc.shape, BoxShape.circle);
      expect(disc.color, const Color(0xFFEF4444));
      expect((disc.border as Border).top.color, Colors.white);
      // Still a + on it, the size of the outline.
      expect(
        find.descendant(of: red, matching: find.byIcon(Icons.add_rounded)),
        findsOneWidget,
      );
      expect(tester.getSize(red), const Size(24, 24));
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    });

    testWidgets('tapping it favorites what is playing, and again undoes it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_playing(NowPlayingItem.fromStation(_station)), signedIn: true),
      );

      await tester.tap(plus);
      await tester.pump();
      expect(red, findsOneWidget);
      expect(_prefs.getStringList('favorite_station_ids'), ['station:1']);

      await tester.tap(red);
      await tester.pump();
      expect(red, findsNothing);
      expect(plus, findsOneWidget);
      expect(_prefs.getStringList('favorite_station_ids'), isEmpty);
    });

    testWidgets('asks a guest to sign in, and favorites nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_playing(NowPlayingItem.fromStation(_station))),
      );

      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Log in to save your favorites'), findsOneWidget);
      expect(red, findsNothing);
      expect(_prefs.getStringList('favorite_station_ids'), isNull);
    });

    testWidgets('follows the song that is playing', (tester) async {
      SharedPreferences.setMockInitialValues({
        'favorite_station_ids': ['media:7'],
      });
      _prefs = await SharedPreferences.getInstance();
      const episode = NowPlayingItem(
        id: 'media:7',
        title: 'Morning News',
        streamUrl: 'https://example.com/7.mp3',
        isLive: false,
      );
      await tester.pumpWidget(_app(_playing(episode)));
      expect(red, findsOneWidget);

      // A different one, not a favorite. (A ProviderScope keeps the overrides
      // it was first built with, so start the tree afresh.)
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _app(_playing(NowPlayingItem.fromStation(_station))),
      );
      expect(red, findsNothing);
    });
  });

  testWidgets('a larger system font doesn\'t overflow the fixed-height bar', (
    tester,
  ) async {
    // The title and subtitle line-heights add up to exactly the 48px the bar
    // gives them at the normal text scale; a device with a bumped-up font
    // size (common on Android — some ship above 1.0 by default) would push
    // that over. The bar deliberately ignores the font-size setting to stay
    // fixed-height, so this shouldn't overflow at any scale.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _app(_playing(NowPlayingItem.fromStation(_station))),
      ),
    );

    expect(tester.takeException(), isNull);
    final bar = find
        .ancestor(of: find.text('Apsara FM97'), matching: find.byType(Material))
        .first;
    expect(tester.getSize(bar).height, 68);
  });

  group('the bar as designed', () {
    Future<void> pumpAt390(
      WidgetTester tester,
      PlaybackState state, {
      Duration? position,
      Duration? duration,
    }) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(state, position: position, duration: duration),
      );
    }

    Finder bar() => find
        .ancestor(of: find.text('Apsara FM97'), matching: find.byType(Material))
        .first;

    testWidgets('is violet, 68 tall, 8 in from the sides, radius 10', (
      tester,
    ) async {
      await pumpAt390(tester, _playing(NowPlayingItem.fromStation(_station)));

      final material = tester.widget<Material>(bar());
      expect(material.color, AppColors.brand400);
      expect(material.borderRadius, BorderRadius.circular(10));
      expect(tester.getSize(bar()), const Size(390 - 16, 68));
      expect(tester.getTopLeft(bar()).dx, 8);
    });

    testWidgets('sits 12 above whatever is below it', (tester) async {
      await pumpAt390(tester, _playing(NowPlayingItem.fromStation(_station)));

      expect(844 - tester.getBottomLeft(bar()).dy, 12);
    });

    testWidgets('has a 44 picture and 24 icons 16 apart', (tester) async {
      await pumpAt390(tester, _playing(NowPlayingItem.fromStation(_station)));

      final picture = find.byType(ArtworkAvatar);
      expect(tester.getSize(picture), const Size(44, 44));
      // 8 in from the bar; centred on the 48-high text, so 10 + 2 down.
      expect(
        tester.getTopLeft(picture) - tester.getTopLeft(bar()),
        const Offset(8, 12),
      );

      final plus = find.byIcon(Icons.add_circle_outline_rounded);
      final pause = find.byIcon(Icons.pause_rounded);
      expect(tester.getSize(plus), const Size(24, 24));
      expect(tester.getSize(pause), const Size(24, 24));
      expect(tester.getTopLeft(pause).dx - tester.getTopRight(plus).dx, 16);
    });

    testWidgets('title and subtitle are light on the violet', (tester) async {
      await pumpAt390(tester, _playing(NowPlayingItem.fromStation(_station)));

      expect(
        tester.widget<Text>(find.text('Apsara FM97')).style!.color,
        const Color(0xFFF8FAFC),
      );
      expect(
        tester.widget<Text>(find.text('News • Live')).style!.color,
        const Color(0xFFCBD5E1),
      );
    });

    Finder wave() => find.byType(PlayingIndicator);

    testWidgets('a sound wave sits on the picture while playing', (
      tester,
    ) async {
      await pumpAt390(tester, _playing(NowPlayingItem.fromStation(_station)));

      expect(wave(), findsOneWidget);
      expect(tester.getSize(wave()), const Size(28.55, 7.9));
    });

    testWidgets('and is gone when paused', (tester) async {
      await pumpAt390(
        tester,
        PlaybackState(
          item: NowPlayingItem.fromStation(_station),
          status: PlaybackStatus.paused,
        ),
      );

      expect(wave(), findsNothing);
    });

    testWidgets('a live stream has only the faint track along the bottom', (
      tester,
    ) async {
      await pumpAt390(tester, _playing(NowPlayingItem.fromStation(_station)));

      // No white stretch: nothing to measure progress against.
      expect(find.byType(FractionallySizedBox), findsNothing);
    });

    testWidgets('on-demand content shows how far through it is', (
      tester,
    ) async {
      const episode = NowPlayingItem(
        id: 'media:7',
        title: 'Morning News',
        streamUrl: 'https://example.com/7.mp3',
        isLive: false,
        subtitle: 'News & Politics',
      );
      await pumpAt390(
        tester,
        _playing(episode),
        position: const Duration(seconds: 15),
        duration: const Duration(seconds: 60),
      );
      await tester.pump();

      final fill = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fill.widthFactor, .25);
    });
  });
}
