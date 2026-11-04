import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/screens/player/play_queue_view.dart';
import 'package:e_radio/views/themes/app_colors.dart';

import 'support/test_fonts.dart';

class _FakePlayer extends AudioPlayerController {
  _FakePlayer(this.initial);

  final PlaybackState initial;
  final played = <String>[];

  @override
  PlaybackState build() => initial;

  @override
  Future<void> play(
    NowPlayingItem item, {
    List<NowPlayingItem>? queue,
    int? queueIndex,
  }) async {
    played.add(item.id);
  }
}

const _morning = NowPlayingItem(
  id: 'media:6',
  title: 'Morning Mix',
  streamUrl: 'https://example.com/6.mp3',
  isLive: false,
  subtitle: 'Songs · Nuth',
);
const _mix = NowPlayingItem(
  id: 'media:7',
  title: 'Evening Mix',
  streamUrl: 'https://example.com/7.mp3',
  isLive: false,
);
const _night = NowPlayingItem(
  id: 'media:8',
  title: 'Night Mix',
  streamUrl: 'https://example.com/8.mp3',
  isLive: false,
);

late _FakePlayer _player;

/// The list page, reached from "/" so that backing out has somewhere to go.
Future<void> _pump(
  WidgetTester tester, {
  List<NowPlayingItem> queue = const [_morning, _mix, _night],
  NowPlayingItem item = _mix,
  int queueIndex = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(
        path: '/start',
        builder: (c, s) => Scaffold(
          body: TextButton(
            onPressed: () => c.push('/'),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(path: '/', builder: (c, s) => const PlayQueueView()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        audioPlayerControllerProvider.overrideWith(
          () => _player = _FakePlayer(
            PlaybackState(
              item: item,
              status: PlaybackStatus.playing,
              queue: queue,
              queueIndex: queueIndex,
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('is a page: a back arrow and "Playlist" over the songs', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Playlist'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    expect(find.text('Morning Mix'), findsOneWidget);
    expect(find.text('Evening Mix'), findsOneWidget);
    expect(find.text('Night Mix'), findsOneWidget);
    expect(find.text('Songs · Nuth'), findsOneWidget);
  });

  testWidgets('outlines the playing song in violet', (tester) async {
    await _pump(tester);

    final outlined = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          ((w.decoration as BoxDecoration).border as Border?)?.top.color ==
              AppColors.brand400,
    );
    expect(outlined, findsOneWidget);
    expect(
      find.descendant(of: outlined, matching: find.text('Evening Mix')),
      findsOneWidget,
    );
  });

  testWidgets('anything played alone is a list of one', (tester) async {
    await _pump(tester, queue: const [], queueIndex: -1);

    expect(find.text('Evening Mix'), findsOneWidget);
    expect(find.text('Morning Mix'), findsNothing);
  });

  testWidgets('tapping another song plays it and stays on the page', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Night Mix'));
    await tester.pumpAndSettle();

    expect(_player.played, ['media:8']);
    expect(find.text('Playlist'), findsOneWidget);
  });

  testWidgets('tapping the playing song goes back to the player', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Evening Mix'));
    await tester.pumpAndSettle();

    expect(find.text('Playlist'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(_player.played, isEmpty);
  });

  testWidgets('the ⋮ on the playing song keeps the secondary actions', (
    tester,
  ) async {
    await _pump(tester);

    // Rows in order: Morning, Evening (playing), Night.
    await tester.tap(find.byIcon(Icons.more_vert_rounded).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Add to favorites'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Add to bookmarks'), findsOneWidget);
    expect(find.text('Remind me'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('the ⋮ on another song offers play, favorite and share', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Add to favorites'), findsOneWidget);
    expect(find.text('Add to bookmarks'), findsNothing);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Comments'), findsNothing);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(_player.played, ['media:6']);
  });
}
