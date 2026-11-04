import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/core/router/app_router.dart';
import 'package:e_radio/data/models/embed_source.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/services/api_client.dart';
import 'package:e_radio/data/services/playback_progress_store.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/recently_played_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';

/// Stands in for the platform player; only records what it was asked to do.
class _FakeJustAudio implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast();
  final events = StreamController<PlaybackEvent>.broadcast();
  int stops = 0;
  final loadedUrls = <Uri>[];

  @override
  Stream<PlayerState> get playerStateStream => states.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;

  @override
  Duration get position => const Duration(minutes: 3);

  @override
  Duration? get duration => const Duration(minutes: 20);

  @override
  Future<Duration?> setAudioSource(
    AudioSource audioSource, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loadedUrls.add((audioSource as UriAudioSource).uri);
    return duration;
  }

  @override
  Future<void> play() => Completer<void>().future;

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends AudioPlayerController {
  _Controller(this.fake);

  final _FakeJustAudio fake;

  @override
  AudioPlayer createPlayer() => fake;
}

class _Api extends ApiClient {
  final posts = <String>[];

  @override
  Future<dynamic> get(String path, {String? token}) async => {
    'data': {'stream_url': _youtubeUrl},
  };

  @override
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    posts.add(path);
    return {'play_count': 7};
  }
}

class _Store implements PlaybackProgressStore {
  final saved = <String, Duration>{};

  @override
  Future<Duration?> fetch(String itemId) async => saved[itemId];

  @override
  Future<void> save(
    String itemId,
    Duration position,
    Duration? duration,
  ) async {
    saved[itemId] = position;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NowPlayingItem _item(int id, String url) => NowPlayingItem(
  id: 'media:$id',
  title: 'Song $id',
  streamUrl: url,
  isLive: false,
);

const _youtubeUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
const _facebookUrl = 'https://www.facebook.com/somepage/videos/1234567890/';

late _FakeJustAudio _player;
late _Api _api;
late _Store _store;
late GoRouter _router;
late ProviderContainer _container;

AudioPlayerController get _controller =>
    _container.read(audioPlayerControllerProvider.notifier);

PlaybackState get _state => _container.read(audioPlayerControllerProvider);

String get _location =>
    _router.routerDelegate.currentConfiguration.lastOrNull!.matchedLocation;

/// An app with just enough router for "/" and "/now-playing" to be told apart.
Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'asked_notification_permission': true,
  });
  final prefs = await SharedPreferences.getInstance();
  _player = _FakeJustAudio();
  _api = _Api();
  _store = _Store();
  _router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      GoRoute(
        path: '/now-playing',
        builder: (context, state) => const SizedBox(),
      ),
    ],
  );
  _container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(_api),
      playbackProgressStoreProvider.overrideWithValue(_store),
      appRouterProvider.overrideWithValue(_router),
      audioPlayerControllerProvider.overrideWith(() => _Controller(_player)),
    ],
  );
  addTearDown(_container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: WidgetsApp.router(
        routerConfig: _router,
        color: const Color(0xFFFFFFFF),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  group('EmbedSource.tryParse', () {
    EmbedSource? parse(String url) => EmbedSource.tryParse(url);

    test('leaves YouTube links alone — the server turns them into audio', () {
      for (final url in [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ?si=abc',
        'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
        'https://www.youtube.com/@somechannel',
      ]) {
        expect(parse(url), isNull, reason: url);
      }
    });

    test('recognises Facebook video, reel and watch links', () {
      for (final url in [
        'https://www.facebook.com/somepage/videos/1234567890/',
        'https://web.facebook.com/somepage/videos/title/1234567890',
        'https://m.facebook.com/watch/?v=1234567890',
        'https://www.facebook.com/watch?v=1234567890',
        'https://www.facebook.com/reel/1234567890',
        'https://www.facebook.com/share/v/AbCdEf/',
        'https://www.facebook.com/share/r/AbCdEf/',
        'https://www.facebook.com/video.php?v=1234567890',
        'https://fb.watch/AbCdEf/',
      ]) {
        expect(parse(url)?.provider, EmbedProvider.facebook, reason: url);
      }
    });

    test('does not take a Facebook page that is not a video', () {
      for (final url in [
        'https://www.facebook.com/somepage',
        'https://www.facebook.com/share/p/AbCdEf/',
        'https://www.facebook.com/profile.php?id=1',
        'https://fb.watch/',
      ]) {
        expect(parse(url), isNull, reason: url);
      }
    });

    test('leaves ordinary stream addresses alone', () {
      for (final url in [
        'https://cdn.example.com/pilot.mp3',
        'https://live.example.com/stream/playlist.m3u8',
        'https://notyoutube.com/watch?v=dQw4w9WgXcQ',
        'https://example.com/?u=https://youtu.be/dQw4w9WgXcQ',
        'not a url',
        '',
      ]) {
        expect(parse(url), isNull, reason: url);
      }
    });

    test('points the Facebook web view at the video plugin', () {
      final uri = parse(_facebookUrl)!.facebookPlayerUri;
      expect(uri.host, 'www.facebook.com');
      expect(uri.path, '/plugins/video.php');
      expect(uri.queryParameters['href'], _facebookUrl);
      expect(uri.queryParameters['autoplay'], 'true');
    });
  });

  test('a live station is never a video link', () {
    const station = NowPlayingItem(
      id: 'station:1',
      title: 'Station',
      streamUrl: _facebookUrl,
      isLive: true,
    );
    expect(station.embed, isNull);
  });

  test(
    'a Facebook link plays as an embed, a YouTube link or an mp3 as audio',
    () {
      final facebook = _item(2, _facebookUrl);
      expect(facebook.embed?.provider, EmbedProvider.facebook);

      expect(_item(1, _youtubeUrl).embed, isNull);
      expect(_item(3, 'https://example.com/3.mp3').embed, isNull);
    },
  );

  group('playing a Facebook song', () {
    testWidgets('opens Now Playing without loading the audio player', (
      tester,
    ) async {
      await _pumpApp(tester);

      unawaited(_controller.play(_item(1, _facebookUrl)));
      await _settle(tester);

      expect(_player.stops, 1, reason: 'silences what was playing');
      expect(_player.loadedUrls, isEmpty);
      expect(_state.item?.id, 'media:1');
      expect(_state.status, PlaybackStatus.paused);
      expect(_location, '/now-playing');
      expect(_api.posts, ['/media-contents/1/play']);
      expect(_container.read(recentlyPlayedProvider), ['media:1']);
      expect(_state.item?.playCount, 7);

      _container.dispose();
    });

    testWidgets('an ordinary song still loads into the audio player', (
      tester,
    ) async {
      await _pumpApp(tester);

      unawaited(_controller.play(_item(1, 'https://example.com/1.mp3')));
      await _settle(tester);

      expect(_player.loadedUrls, [Uri.parse('https://example.com/1.mp3')]);
      expect(_location, '/');

      _container.dispose();
    });

    testWidgets('does not stack a second Now Playing on the first', (
      tester,
    ) async {
      await _pumpApp(tester);

      unawaited(_controller.play(_item(1, _facebookUrl)));
      await _settle(tester);
      unawaited(_controller.play(_item(2, _facebookUrl)));
      await _settle(tester);

      expect(_state.item?.id, 'media:2');
      _router.pop();
      await _settle(tester);
      expect(_location, '/');

      _container.dispose();
    });

    testWidgets(
      'the player reports playing and paused, for its own item only',
      (tester) async {
        await _pumpApp(tester);
        unawaited(_controller.play(_item(1, _facebookUrl)));
        await _settle(tester);

        _controller.reportEmbedPlaying('media:1', true);
        expect(_state.status, PlaybackStatus.playing);

        _controller.reportEmbedPlaying('media:2', false);
        expect(_state.status, PlaybackStatus.playing);

        _controller.reportEmbedPlaying('media:1', false);
        expect(_state.status, PlaybackStatus.paused);

        _container.dispose();
      },
    );

    testWidgets('the mini player\'s play button brings the video back', (
      tester,
    ) async {
      await _pumpApp(tester);
      unawaited(_controller.play(_item(1, _facebookUrl)));
      await _settle(tester);
      _router.pop();
      await _settle(tester);
      expect(_location, '/');

      await _controller.togglePlayPause();
      await _settle(tester);

      expect(_location, '/now-playing');
      expect(_player.loadedUrls, isEmpty);

      _container.dispose();
    });

    testWidgets('never saves the audio player\'s place as the video\'s', (
      tester,
    ) async {
      await _pumpApp(tester);
      unawaited(_controller.play(_item(1, _facebookUrl)));
      await _settle(tester);

      // Stopping asks to save the place; the fake player claims 3:00, which
      // belongs to some earlier song, not this video.
      await _controller.stop();

      expect(_store.saved, isEmpty);

      _container.dispose();
    });
  });
}
