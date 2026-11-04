import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/core/router/app_router.dart';
import 'package:e_radio/core/supports/open_release_alert.dart';
import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/repositories/media_content_repository.dart';
import 'package:e_radio/data/services/release_alerts.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';

import 'support/fake_media_list.dart';

/// A player that only notes what it was asked to play.
class _FakePlayer extends AudioPlayerController {
  final played = <(NowPlayingItem, int?)>[];

  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> play(
    NowPlayingItem item, {
    List<NowPlayingItem>? queue,
    int? queueIndex,
  }) async {
    played.add((item, queueIndex));
  }
}

MediaContent _release(String id, {String? streamUrl}) => MediaContent(
  id: id,
  title: 'Release $id',
  mediaType: 'audio',
  streamUrl: streamUrl ?? 'https://example.com/$id.mp3',
);

/// The app's pages as one-word placeholders, on the app's own paths.
GoRouter _router() => GoRouter(
  initialLocation: '/explore',
  routes: [
    for (final page in ['explore', 'notifications', 'now-playing'])
      GoRoute(
        path: '/$page',
        builder: (context, state) => Scaffold(body: Text(page)),
      ),
  ],
);

late ProviderContainer _container;

Future<void> _pump(
  WidgetTester tester, {
  List<MediaContent> releases = const [],
  bool seenOnboarding = true,
  _FakePlayer Function() player = _FakePlayer.new,
}) async {
  SharedPreferences.setMockInitialValues({
    'has_seen_onboarding': seenOnboarding,
  });
  final prefs = await SharedPreferences.getInstance();
  final router = _router();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appRouterProvider.overrideWithValue(router),
        audioPlayerControllerProvider.overrideWith(player),
        newReleaseMediaContentsProvider.overrideWith(
          () => FakeMediaList(releases),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  _container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

_FakePlayer get _player =>
    _container.read(audioPlayerControllerProvider.notifier) as _FakePlayer;

void main() {
  testWidgets('an alert for several releases opens the Notifications page', (
    tester,
  ) async {
    await _pump(tester, releases: [_release('1'), _release('2')]);

    await openReleaseAlert(_container, kReleasesPayload);
    await tester.pumpAndSettle();

    expect(find.text('notifications'), findsOneWidget);
    expect(_player.played, isEmpty);
  });

  testWidgets('an alert for one release plays it and opens Now Playing', (
    tester,
  ) async {
    await _pump(tester, releases: [_release('1'), _release('2')]);

    await openReleaseAlert(_container, 'release:2');
    await tester.pumpAndSettle();

    expect(find.text('now-playing'), findsOneWidget);
    expect(_player.played, hasLength(1));
    expect(_player.played.single.$1.id, 'media:2');
    // Next and previous step through the list it came from.
    expect(_player.played.single.$2, 1);
  });

  testWidgets('a release that is already playing is opened, not paused', (
    tester,
  ) async {
    await _pump(tester, releases: [_release('1')], player: _PlayingOne.new);

    await openReleaseAlert(_container, 'release:1');
    await tester.pumpAndSettle();

    expect(find.text('now-playing'), findsOneWidget);
    expect(_player.played, isEmpty);
  });

  testWidgets('stays on the Notifications page for a release it cannot play', (
    tester,
  ) async {
    await _pump(
      tester,
      releases: [
        MediaContent(id: '1', title: 'An article', mediaType: 'article'),
      ],
    );

    await openReleaseAlert(_container, 'release:1');
    await tester.pumpAndSettle();

    expect(find.text('notifications'), findsOneWidget);
    expect(find.text('now-playing'), findsNothing);
    expect(_player.played, isEmpty);
  });

  testWidgets('stays on the Notifications page for a release not in the list', (
    tester,
  ) async {
    await _pump(tester, releases: [_release('1')]);

    await openReleaseAlert(_container, 'release:99');
    await tester.pumpAndSettle();

    expect(find.text('notifications'), findsOneWidget);
    expect(_player.played, isEmpty);
  });

  testWidgets('does nothing before the welcome pages have been seen', (
    tester,
  ) async {
    await _pump(tester, releases: [_release('1')], seenOnboarding: false);

    await openReleaseAlert(_container, 'release:1');
    await tester.pumpAndSettle();

    expect(find.text('explore'), findsOneWidget);
    expect(_player.played, isEmpty);
  });
}

/// A player with release 1 already loaded.
class _PlayingOne extends _FakePlayer {
  @override
  PlaybackState build() => PlaybackState(
    item: NowPlayingItem(
      id: 'media:1',
      title: 'Release 1',
      streamUrl: 'https://example.com/1.mp3',
      isLive: false,
    ),
  );
}
