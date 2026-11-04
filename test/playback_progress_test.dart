import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/services/api_client.dart';
import 'package:e_radio/data/services/playback_progress_store.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/recently_played_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';

/// Stands in for the platform player. [play] — like just_audio's — only
/// finishes once playback pauses or ends, which is what once hid the saving.
class _FakeJustAudio implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast();
  final events = StreamController<PlaybackEvent>.broadcast();
  Duration where = Duration.zero;
  final loadedAt = <Duration?>[];
  final loadedUrls = <Uri>[];
  final playCall = Completer<void>();

  /// How many of the next loads fail, the way a dropped request does.
  int failLoads = 0;

  @override
  Stream<PlayerState> get playerStateStream => states.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;

  @override
  Duration get position => where;

  @override
  Duration? get duration => const Duration(minutes: 20);

  @override
  Future<Duration?> setAudioSource(
    AudioSource audioSource, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loadedAt.add(initialPosition);
    loadedUrls.add((audioSource as UriAudioSource).uri);
    if (failLoads > 0) {
      failLoads--;
      // The platform reports a failed load on the event stream too.
      events.addError(PlayerException(0, 'Source error', null));
      throw PlayerException(0, 'Source error', null);
    }
    where = initialPosition ?? Duration.zero;
    return duration;
  }

  @override
  Future<void> play() => playCall.future;

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

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

class _Api extends ApiClient {
  /// Every path asked for, in order.
  final gets = <String>[];

  @override
  Future<dynamic> get(String path, {String? token}) async {
    gets.add(path);
    return {
      'data': {'stream_url': 'https://example.com/stream.mp3'},
    };
  }

  @override
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async => {'play_count': 1};
}

NowPlayingItem _song(int id) => NowPlayingItem(
  id: 'media:$id',
  title: 'Song $id',
  streamUrl: 'https://example.com/$id.mp3',
  isLive: false,
);

/// On-demand media filed under the category [slug] (`song`, `podcast`, …).
NowPlayingItem _track(int id, String slug) => NowPlayingItem(
  id: 'media:$id',
  title: 'Track $id',
  streamUrl: 'https://example.com/$id.mp3',
  isLive: false,
  categorySlug: slug,
);

late _FakeJustAudio _player;
late _Api _api;
late _Store _store;
late ProviderContainer _container;

AudioPlayerController get _controller =>
    _container.read(audioPlayerControllerProvider.notifier);

Future<void> _setUp() async {
  SharedPreferences.setMockInitialValues({
    // So the first play doesn't stop to ask about notifications.
    'asked_notification_permission': true,
  });
  final prefs = await SharedPreferences.getInstance();
  _player = _FakeJustAudio();
  _store = _Store();
  _api = _Api();
  _container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      playbackProgressStoreProvider.overrideWithValue(_store),
      apiClientProvider.overrideWithValue(_api),
      audioPlayerControllerProvider.overrideWith(() => _Controller(_player)),
    ],
  );
  addTearDown(_container.dispose);
}

/// Lets what [AudioPlayerController.play] awaits go by.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// [_settle], then past the short pause before a failed load is tried again,
/// then [_settle] once more for the retry itself.
Future<void> _settleThroughRetry(WidgetTester tester) async {
  await _settle(tester);
  await tester.pump(const Duration(seconds: 1));
  await _settle(tester);
}

/// A place saved part-way through a song.
const _place = Duration(minutes: 2, seconds: 5);

/// A test that closes the controller at the end — its save timer must not
/// outlive the test.
void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    _container.dispose();
  });
}

void main() {
  _test('saves the place as it plays, not only once it pauses', (tester) async {
    await _setUp();
    // Not awaited: it finishes only when playback pauses.
    unawaited(_controller.play(_song(1)));
    await _settle(tester);

    _player.where = const Duration(minutes: 1, seconds: 10);
    _player.states.add(PlayerState(true, ProcessingState.ready));
    await tester.pump(const Duration(seconds: 6));

    expect(_store.saved['media:1'], const Duration(minutes: 1, seconds: 10));
  });

  _test('writes the history as it starts, not when it pauses', (tester) async {
    await _setUp();
    unawaited(_controller.play(_song(1)));
    await _settle(tester);

    expect(_container.read(recentlyPlayedProvider), ['media:1']);
    expect(_container.read(recentlyPlayedAtProvider).keys, ['media:1']);
  });

  _test('keeps the place of the song it moves on from', (tester) async {
    await _setUp();
    unawaited(_controller.play(_song(1)));
    await _settle(tester);

    // Mid-song, before any save has come round, another is started.
    _player.where = const Duration(minutes: 3);
    unawaited(_controller.play(_song(2)));
    await _settle(tester);

    expect(_store.saved['media:1'], const Duration(minutes: 3));
    expect(_store.saved.containsKey('media:2'), isFalse);
  });

  _test('resumes other on-demand media from where it was left', (tester) async {
    await _setUp();
    _store.saved['media:1'] = _place;

    unawaited(_controller.play(_song(1)));
    await _settle(tester);

    expect(_player.loadedAt, [_place]);
  });

  _test('a podcast episode resumes from where it was left', (tester) async {
    await _setUp();
    _store.saved['media:1'] = _place;

    unawaited(_controller.play(_track(1, 'podcast')));
    await _settle(tester);

    expect(_player.loadedAt, [_place]);
  });

  for (final slug in ['song', 'ambient-music']) {
    _test('"$slug" always starts from the beginning, even with a place '
        'saved', (tester) async {
      await _setUp();
      _store.saved['media:1'] = _place;

      unawaited(_controller.play(_track(1, slug)));
      await _settle(tester);

      expect(_player.loadedAt, [null]);
      expect(_player.where, Duration.zero);
    });

    _test('"$slug" never has its place kept', (tester) async {
      await _setUp();
      unawaited(_controller.play(_track(1, slug)));
      await _settle(tester);
      _player.states.add(PlayerState(true, ProcessingState.ready));
      await tester.pump();

      // Part-way through: the save timer comes round…
      _player.where = const Duration(minutes: 1, seconds: 10);
      await tester.pump(const Duration(seconds: 6));
      // …it is paused from outside the app, the app goes to the background…
      _player.states.add(PlayerState(false, ProcessingState.ready));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      // …and another song takes over.
      unawaited(_controller.play(_track(2, slug)));
      await _settle(tester);

      expect(_store.saved, isEmpty);
    });
  }

  _test('a load that drops is tried once more, from the same place', (
    tester,
  ) async {
    await _setUp();
    _store.saved['media:1'] = _place;
    _player.failLoads = 1;

    unawaited(_controller.play(_song(1)));
    await _settleThroughRetry(tester);

    expect(_player.loadedAt, [_place, _place]);
    expect(
      _container.read(audioPlayerControllerProvider).status,
      isNot(PlaybackStatus.error),
    );
  });

  _test('a song starts from the address it already has, without asking first', (
    tester,
  ) async {
    await _setUp();

    unawaited(_controller.play(_song(1)));
    await _settle(tester);

    expect(_player.loadedUrls, [Uri.parse('https://example.com/1.mp3')]);
    expect(_api.gets, isEmpty);
  });

  _test('a load that fails asks the server for the current address', (
    tester,
  ) async {
    await _setUp();
    _player.failLoads = 1;

    unawaited(_controller.play(_song(1)));
    await _settleThroughRetry(tester);

    expect(_api.gets, ['/media-contents/1']);
    expect(_player.loadedUrls, [
      Uri.parse('https://example.com/1.mp3'),
      Uri.parse('https://example.com/stream.mp3'),
    ]);
  });

  _test('a load that keeps failing shows the failure', (tester) async {
    await _setUp();
    _player.failLoads = 2;

    unawaited(_controller.play(_song(1)));
    await _settleThroughRetry(tester);

    expect(_player.loadedAt, hasLength(2));
    expect(
      _container.read(audioPlayerControllerProvider).status,
      PlaybackStatus.error,
    );
  });

  _test('a live stream survives more than one transient load failure', (
    tester,
  ) async {
    await _setUp();
    _player.failLoads = 2;

    unawaited(
      _controller.play(
        const NowPlayingItem(
          id: 'station:11',
          title: 'Apsara FM97',
          streamUrl: 'https://live.ams.com.kh/radio97/stream/playlist.m3u8',
          isLive: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await _settle(tester);

    expect(_player.loadedAt, hasLength(3));
    expect(
      _container.read(audioPlayerControllerProvider).status,
      isNot(PlaybackStatus.error),
    );
  });

  const station = NowPlayingItem(
    id: 'station:10',
    title: 'AMS Pov',
    streamUrl: 'http://studio.devams.site/hls/fm97/live.m3u8',
    isLive: true,
  );

  _test('a live stream that fails while playing is loaded again', (
    tester,
  ) async {
    await _setUp();
    unawaited(_controller.play(station));
    await _settle(tester);
    _player.states.add(PlayerState(true, ProcessingState.ready));
    await tester.pump();
    expect(_player.loadedAt, hasLength(1));

    // The stall that outlasts the playlist: a segment is gone, so a 404.
    _player.events.addError(PlayerException(404, 'Response code: 404', null));
    await _settle(tester);

    expect(_player.loadedAt, hasLength(2));
    expect(
      _container.read(audioPlayerControllerProvider).status,
      isNot(PlaybackStatus.error),
    );
  });

  _test('a live stream that keeps failing while playing shows the failure', (
    tester,
  ) async {
    await _setUp();
    unawaited(_controller.play(station));
    await _settle(tester);

    for (var i = 0; i < 4; i++) {
      _player.events.addError(PlayerException(404, 'Response code: 404', null));
      await _settle(tester);
    }

    // The first load, then three more, then it stops trying.
    expect(_player.loadedAt, hasLength(4));
    expect(
      _container.read(audioPlayerControllerProvider).status,
      PlaybackStatus.error,
    );
  });

  _test('a song that fails while playing is left alone', (tester) async {
    await _setUp();
    unawaited(_controller.play(_song(1)));
    await _settle(tester);

    _player.events.addError(PlayerException(0, 'Source error', null));
    await _settle(tester);

    expect(_player.loadedAt, hasLength(1));
  });

  _test('keeps the place when paused from outside the app', (tester) async {
    await _setUp();
    unawaited(_controller.play(_song(1)));
    await _settle(tester);
    _player.states.add(PlayerState(true, ProcessingState.ready));
    await tester.pump();

    // The notification's pause button: the player stops, the app isn't asked.
    _player.where = const Duration(minutes: 7);
    _player.states.add(PlayerState(false, ProcessingState.ready));
    await tester.pump();

    expect(_store.saved['media:1'], const Duration(minutes: 7));
  });

  _test('keeps the place when the app goes to the background', (tester) async {
    await _setUp();
    unawaited(_controller.play(_song(1)));
    await _settle(tester);

    _player.where = const Duration(minutes: 4);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(_store.saved['media:1'], const Duration(minutes: 4));
  });

  _test('moves on to the next song when one finishes', (tester) async {
    await _setUp();
    final queue = [_song(1), _song(2), _song(3)];
    unawaited(_controller.play(queue[0], queue: queue, queueIndex: 0));
    await _settle(tester);
    // just_audio keeps `playing` true when the song ends.
    _player.states.add(PlayerState(true, ProcessingState.ready));
    await tester.pump();

    _player.states.add(PlayerState(true, ProcessingState.completed));
    await _settle(tester);

    final playback = _container.read(audioPlayerControllerProvider);
    expect(playback.item?.id, 'media:2');
    expect(playback.queueIndex, 1);
    expect(_player.loadedAt, hasLength(2));
  });

  _test('does not skip a song if the end is reported twice', (tester) async {
    await _setUp();
    final queue = [_song(1), _song(2), _song(3)];
    unawaited(_controller.play(queue[0], queue: queue, queueIndex: 0));
    await _settle(tester);
    _player.states.add(PlayerState(true, ProcessingState.ready));
    await tester.pump();

    _player.states.add(PlayerState(true, ProcessingState.completed));
    _player.states.add(PlayerState(true, ProcessingState.completed));
    await _settle(tester);

    expect(_container.read(audioPlayerControllerProvider).item?.id, 'media:2');
  });

  _test('stops after the last song of the list', (tester) async {
    await _setUp();
    final queue = [_song(1), _song(2)];
    unawaited(_controller.play(queue[1], queue: queue, queueIndex: 1));
    await _settle(tester);
    _player.states.add(PlayerState(true, ProcessingState.ready));
    await tester.pump();

    _player.states.add(PlayerState(true, ProcessingState.completed));
    await _settle(tester);

    final playback = _container.read(audioPlayerControllerProvider);
    expect(playback.item?.id, 'media:2');
    expect(playback.status, PlaybackStatus.paused);
    expect(_player.loadedAt, hasLength(1));
  });

  _test('a live station that ends is not treated as a finished song', (
    tester,
  ) async {
    await _setUp();
    const live = NowPlayingItem(
      id: 'station:1',
      title: 'Live',
      streamUrl: 'https://example.com/live',
      isLive: true,
    );
    unawaited(_controller.play(live, queue: [live, _song(1)], queueIndex: 0));
    await _settle(tester);
    _player.states.add(PlayerState(true, ProcessingState.ready));
    await tester.pump();

    _player.states.add(PlayerState(true, ProcessingState.completed));
    await _settle(tester);

    expect(
      _container.read(audioPlayerControllerProvider).item?.id,
      'station:1',
    );
    expect(_player.loadedAt, hasLength(1));
  });

  _test('a live station has no place to keep', (tester) async {
    await _setUp();
    unawaited(
      _controller.play(
        const NowPlayingItem(
          id: 'station:1',
          title: 'Live',
          streamUrl: 'https://example.com/live',
          isLive: true,
        ),
      ),
    );
    await _settle(tester);

    _player.where = const Duration(minutes: 9);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 6));

    expect(_store.saved, isEmpty);
  });
}
