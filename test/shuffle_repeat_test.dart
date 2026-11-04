import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/services/api_client.dart';
import 'package:e_radio/data/services/playback_progress_store.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';

/// Stands in for the platform player; records what it was asked to load and do.
class _FakeJustAudio implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast();
  final events = StreamController<PlaybackEvent>.broadcast();
  final loadedUrls = <Uri>[];
  final seeks = <Duration?>[];
  var plays = 0;

  @override
  Stream<PlayerState> get playerStateStream => states.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;

  @override
  Duration get position => Duration.zero;

  @override
  Duration? get duration => const Duration(minutes: 3);

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
  Future<void> seek(Duration? position, {int? index}) async =>
      seeks.add(position);

  /// Like just_audio's, it only finishes once playback pauses — never here.
  @override
  Future<void> play() {
    plays++;
    return Completer<void>().future;
  }

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
  @override
  Future<Duration?> fetch(String itemId) async => null;

  @override
  Future<void> save(
    String itemId,
    Duration position,
    Duration? duration,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api extends ApiClient {
  @override
  Future<dynamic> get(String path, {String? token}) async => {
    'data': {'stream_url': 'https://example.com/stream.mp3'},
  };

  @override
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async => {'play_count': 1};
}

NowPlayingItem _item(int id, {String category = 'song'}) => NowPlayingItem(
  id: 'media:$id',
  title: 'Track $id',
  streamUrl: 'https://example.com/$id.mp3',
  isLive: false,
  categorySlug: category,
);

List<NowPlayingItem> _list(int count, {String category = 'song'}) => [
  for (var i = 1; i <= count; i++) _item(i, category: category),
];

late _FakeJustAudio _player;
late ProviderContainer _container;

AudioPlayerController get _controller =>
    _container.read(audioPlayerControllerProvider.notifier);

PlaybackState get _state => _container.read(audioPlayerControllerProvider);

List<String> get _queueIds => [for (final item in _state.queue) item.id];

Future<void> _setUp() async {
  SharedPreferences.setMockInitialValues({
    // So the first play doesn't stop to ask about notifications.
    'asked_notification_permission': true,
  });
  final prefs = await SharedPreferences.getInstance();
  _player = _FakeJustAudio();
  _container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      playbackProgressStoreProvider.overrideWithValue(_Store()),
      apiClientProvider.overrideWithValue(_Api()),
      audioPlayerControllerProvider.overrideWith(() => _Controller(_player)),
    ],
  );
  addTearDown(_container.dispose);
}

/// Lets what [AudioPlayerController.play] awaits go by.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

/// Plays [queue]'s song at [index] and gets it to the "playing" state.
Future<void> _start(
  WidgetTester tester,
  List<NowPlayingItem> queue, {
  int index = 0,
}) async {
  // Not awaited: it finishes only when playback pauses.
  unawaited(_controller.play(queue[index], queue: queue, queueIndex: index));
  await _settle(tester);
  _player.states.add(PlayerState(true, ProcessingState.ready));
  await _settle(tester);
}

/// The song ends on its own.
Future<void> _finish(WidgetTester tester) async {
  _player.states.add(PlayerState(true, ProcessingState.completed));
  await _settle(tester);
}

void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await _setUp();
    await body(tester);
    _container.dispose();
  });
}

void main() {
  group('shuffle', () {
    _test('keeps the song playing first and puts the rest in a new order, '
        'then restores the order when turned off', (tester) async {
      final songs = _list(10);
      await _start(tester, songs, index: 3);
      _controller.shuffleRandom = Random(7);

      _controller.toggleShuffle();

      expect(_state.shuffle, isTrue);
      expect(_state.item?.id, 'media:4');
      expect(_state.queueIndex, 0);
      expect(_queueIds.first, 'media:4');
      expect(_queueIds.toSet(), {for (final s in songs) s.id});
      expect(_queueIds, hasLength(10));
      expect(_queueIds, isNot([for (final s in songs) s.id]));

      _controller.toggleShuffle();

      expect(_state.shuffle, isFalse);
      expect(_queueIds, [for (final s in songs) s.id]);
      expect(_state.queueIndex, 3);
    });

    _test('makes next follow the shuffled order', (tester) async {
      await _start(tester, _list(8));
      _controller.shuffleRandom = Random(3);
      _controller.toggleShuffle();
      final expectedNext = _state.queue[1];

      unawaited(_controller.playNext());
      await _settle(tester);

      expect(_state.item?.id, expectedNext.id);
      expect(_player.loadedUrls.last, Uri.parse(expectedNext.streamUrl));
    });

    _test('shuffles a new list around the song picked, but not the queue '
        'already in play when "up next" hands it back', (tester) async {
      await _start(tester, _list(2));
      _controller.shuffleRandom = Random(5);
      _controller.toggleShuffle();

      final fresh = _list(9);
      unawaited(_controller.play(fresh[4], queue: fresh, queueIndex: 4));
      await _settle(tester);

      expect(_state.shuffle, isTrue);
      expect(_queueIds.first, 'media:5');
      expect(_state.queueIndex, 0);
      expect(_queueIds.toSet(), {for (final s in fresh) s.id});
      expect(_queueIds, isNot([for (final s in fresh) s.id]));

      final inPlay = _queueIds;
      unawaited(
        _controller.play(_state.queue[3], queue: _state.queue, queueIndex: 3),
      );
      await _settle(tester);

      expect(_queueIds, inPlay);
      expect(_state.queueIndex, 3);
    });

    _test('does not reorder a podcast list', (tester) async {
      final episodes = _list(5, category: 'podcast');
      await _start(tester, episodes);

      _controller.toggleShuffle();

      expect(_queueIds, [for (final e in episodes) e.id]);
      expect(_state.queueIndex, 0);
    });
  });

  group('repeat', () {
    _test('cycles off, all, one, off', (tester) async {
      await _start(tester, _list(3));
      expect(_state.repeat, RepeatMode.off);

      _controller.cycleRepeat();
      expect(_state.repeat, RepeatMode.all);
      _controller.cycleRepeat();
      expect(_state.repeat, RepeatMode.one);
      _controller.cycleRepeat();
      expect(_state.repeat, RepeatMode.off);
    });

    _test('repeat all lets next and previous step round the ends of the list', (
      tester,
    ) async {
      final songs = _list(3);
      await _start(tester, songs, index: 2);
      expect(_state.canSkipNext, isFalse, reason: 'repeat is off');

      _controller.cycleRepeat();
      expect(_state.canSkipNext, isTrue);

      unawaited(_controller.playNext());
      await _settle(tester);
      expect(_state.item?.id, 'media:1');
      expect(_state.queueIndex, 0);

      unawaited(_controller.playPrevious());
      await _settle(tester);
      expect(_state.item?.id, 'media:3');
      expect(_state.queueIndex, 2);
    });

    _test('with repeat off, the last song has no next', (tester) async {
      await _start(tester, _list(3), index: 2);
      final loaded = _player.loadedUrls.length;

      await _controller.playNext();
      await _settle(tester);

      expect(_player.loadedUrls, hasLength(loaded));
      expect(_state.item?.id, 'media:3');
    });

    _test('a song that ends moves on to the next one', (tester) async {
      await _start(tester, _list(3));

      await _finish(tester);

      expect(_state.item?.id, 'media:2');
    });

    _test('with repeat off, the last song ending stops there', (tester) async {
      await _start(tester, _list(3), index: 2);
      final loaded = _player.loadedUrls.length;

      await _finish(tester);

      expect(_player.loadedUrls, hasLength(loaded));
      expect(_state.item?.id, 'media:3');
      expect(_state.status, PlaybackStatus.paused);
    });

    _test('repeat one plays the same song again from the start', (
      tester,
    ) async {
      await _start(tester, _list(3));
      _controller.cycleRepeat();
      _controller.cycleRepeat();
      expect(_state.repeat, RepeatMode.one);
      final loaded = _player.loadedUrls.length;

      await _finish(tester);

      expect(_player.seeks, [Duration.zero]);
      expect(_player.loadedUrls, hasLength(loaded), reason: 'not loaded again');
      expect(_state.item?.id, 'media:1');
      expect(_state.status, PlaybackStatus.playing);
    });

    _test('repeat all starts the list over after its last song', (
      tester,
    ) async {
      final songs = _list(3);
      await _start(tester, songs, index: 2);
      _controller.cycleRepeat();

      await _finish(tester);

      expect(_state.item?.id, 'media:1');
      expect(_player.loadedUrls.last, Uri.parse(songs.first.streamUrl));
    });

    _test('repeat all with a single song plays it again', (tester) async {
      await _start(tester, _list(1));
      _controller.cycleRepeat();
      final loaded = _player.loadedUrls.length;

      await _finish(tester);

      expect(_player.seeks, [Duration.zero]);
      expect(_player.loadedUrls, hasLength(loaded));
    });

    _test('does not act on a podcast, whatever repeat is set to', (
      tester,
    ) async {
      await _start(tester, _list(3, category: 'podcast'), index: 2);
      _controller.cycleRepeat();
      _controller.cycleRepeat();
      expect(_state.repeat, RepeatMode.one);
      expect(_state.activeRepeat, RepeatMode.off);
      final loaded = _player.loadedUrls.length;

      await _finish(tester);

      expect(_player.seeks, isEmpty);
      expect(_player.loadedUrls, hasLength(loaded));
      expect(_state.status, PlaybackStatus.paused);
    });
  });

  group('the modes stay chosen', () {
    _test('from song to song, and after stopping', (tester) async {
      await _start(tester, _list(6));
      _controller.shuffleRandom = Random(2);
      _controller.toggleShuffle();
      _controller.cycleRepeat();

      unawaited(_controller.playNext());
      await _settle(tester);
      expect(_state.shuffle, isTrue);
      expect(_state.repeat, RepeatMode.all);

      await _controller.stop();
      expect(_state.item, isNull);
      expect(_state.shuffle, isTrue);
      expect(_state.repeat, RepeatMode.all);
    });
  });
}
