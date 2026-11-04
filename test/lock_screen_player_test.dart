import 'dart:async';

import 'package:audio_service/audio_service.dart'
    show AudioProcessingState, MediaAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/services/api_client.dart';
import 'package:e_radio/data/services/playback_progress_store.dart';
import 'package:e_radio/data/services/radio_audio_handler.dart';
import 'package:e_radio/providers/audio_handler_provider.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';

/// Stands in for the platform player, down to what the lock-screen handler
/// reads off it.
class _FakeJustAudio implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast();
  final events = StreamController<PlaybackEvent>.broadcast();
  final durations = StreamController<Duration?>.broadcast();
  final loadedUrls = <Uri>[];
  var plays = 0;
  var pauses = 0;
  var stops = 0;
  var isPlaying = false;
  var processing = ProcessingState.idle;

  /// What the player is doing, as it would report it.
  void emit(bool playing, ProcessingState state) {
    isPlaying = playing;
    processing = state;
    states.add(PlayerState(playing, state));
  }

  @override
  Stream<PlayerState> get playerStateStream => states.stream;

  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;

  @override
  Stream<Duration?> get durationStream => durations.stream;

  @override
  bool get playing => isPlaying;

  @override
  ProcessingState get processingState => processing;

  @override
  Duration get position => Duration.zero;

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  double get speed => 1.0;

  @override
  Duration? get duration => null;

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
  Future<void> seek(Duration? position, {int? index}) async {}

  /// Like just_audio's, it only finishes once playback pauses — never here.
  @override
  Future<void> play() {
    plays++;
    return Completer<void>().future;
  }

  @override
  Future<void> pause() async => pauses++;

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

NowPlayingItem _song(int id) => NowPlayingItem(
  id: 'media:$id',
  title: 'Track $id',
  subtitle: 'Song · Artist $id',
  artworkUrl: 'https://example.com/art$id.jpg',
  streamUrl: 'https://example.com/$id.mp3',
  isLive: false,
  categorySlug: 'song',
);

List<NowPlayingItem> _songs(int count) => [
  for (var i = 1; i <= count; i++) _song(i),
];

const _station = NowPlayingItem(
  id: 'station:1',
  title: 'APSARA FM97',
  subtitle: 'News',
  artworkUrl: 'https://example.com/apsara.png',
  streamUrl: 'https://example.com/live.m3u8',
  isLive: true,
);

late _FakeJustAudio _player;
late RadioAudioHandler _handler;
late ProviderContainer _container;

AudioPlayerController get _controller =>
    _container.read(audioPlayerControllerProvider.notifier);

PlaybackState get _state => _container.read(audioPlayerControllerProvider);

/// The buttons on the card, left to right.
List<MediaAction> get _buttons => [
  for (final control in _handler.playbackState.value.controls) control.action,
];

Future<void> _setUp() async {
  SharedPreferences.setMockInitialValues({
    // So the first play doesn't stop to ask about notifications.
    'asked_notification_permission': true,
  });
  final prefs = await SharedPreferences.getInstance();
  _player = _FakeJustAudio();
  // The real handler, as the app has it — only the system service behind it is
  // left out.
  _handler = RadioAudioHandler();
  _container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      playbackProgressStoreProvider.overrideWithValue(_Store()),
      apiClientProvider.overrideWithValue(_Api()),
      audioHandlerProvider.overrideWithValue(_handler),
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

/// Plays [queue]'s item at [index] and gets it to the "playing" state.
Future<void> _start(
  WidgetTester tester,
  List<NowPlayingItem> queue, {
  int index = 0,
}) async {
  // Not awaited: it finishes only when playback pauses.
  unawaited(_controller.play(queue[index], queue: queue, queueIndex: index));
  await _settle(tester);
  _player.emit(true, ProcessingState.ready);
  await _settle(tester);
}

void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await _setUp();
    await body(tester);
    // Stops the progress timer before the test ends.
    _container.dispose();
  });
}

void main() {
  group('The card on the lock screen', () {
    _test('shows what is playing', (tester) async {
      await _start(tester, _songs(3));

      final shown = _handler.mediaItem.value!;
      expect(shown.title, 'Track 1');
      expect(shown.artist, 'Song · Artist 1');
      expect(shown.artUri, Uri.parse('https://example.com/art1.jpg'));
      expect(shown.isLive, isFalse);
    });

    _test('is up while a song loads, before it plays', (tester) async {
      unawaited(_controller.play(_song(1), queue: _songs(3), queueIndex: 0));
      await _settle(tester);

      expect(_handler.mediaItem.value?.title, 'Track 1');
    });

    _test('gets the length of a song once it is known', (tester) async {
      await _start(tester, _songs(3));
      expect(_handler.mediaItem.value!.duration, isNull);

      _player.durations.add(const Duration(minutes: 3, seconds: 20));
      await _settle(tester);

      expect(
        _handler.mediaItem.value!.duration,
        const Duration(minutes: 3, seconds: 20),
      );
    });

    _test('marks a station live, with no length to seek', (tester) async {
      await _start(tester, const [_station]);

      expect(_handler.mediaItem.value!.title, 'APSARA FM97');
      expect(_handler.mediaItem.value!.isLive, isTrue);

      _player.durations.add(const Duration(hours: 5));
      await _settle(tester);
      expect(_handler.mediaItem.value!.duration, isNull);
    });
  });

  // Starting a song (and play) is not awaited anywhere below: it finishes only
  // when playback pauses, like just_audio's own play().
  group('Previous and next on the card', () {
    _test('are both there in the middle of a list', (tester) async {
      await _start(tester, _songs(3), index: 1);

      expect(_buttons, [
        MediaAction.skipToPrevious,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.skipToNext,
      ]);
    });

    _test('leave out previous on the first song', (tester) async {
      await _start(tester, _songs(3), index: 0);

      expect(_buttons, [
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.skipToNext,
      ]);
    });

    _test('leave out next on the last song', (tester) async {
      await _start(tester, _songs(3), index: 2);

      expect(_buttons, [
        MediaAction.skipToPrevious,
        MediaAction.pause,
        MediaAction.stop,
      ]);
    });

    _test('are not offered for something played on its own', (tester) async {
      await _start(tester, const [_station]);

      expect(_buttons, [MediaAction.pause, MediaAction.stop]);
    });

    _test('follow the song as it changes', (tester) async {
      await _start(tester, _songs(3), index: 0);
      expect(_buttons, isNot(contains(MediaAction.skipToPrevious)));

      unawaited(_controller.playNext());
      await _settle(tester);

      expect(_buttons, contains(MediaAction.skipToPrevious));
      expect(_buttons, contains(MediaAction.skipToNext));
    });

    _test('keep stop out of the compact card', (tester) async {
      await _start(tester, _songs(3), index: 1);

      // [previous, pause, stop, next] — all but stop.
      expect(_handler.playbackState.value.androidCompactActionIndices, [
        0,
        1,
        3,
      ]);
    });

    _test('next on the card plays the next song', (tester) async {
      await _start(tester, _songs(3), index: 0);

      unawaited(_handler.skipToNext());
      await _settle(tester);

      expect(_state.item?.id, 'media:2');
      expect(_player.loadedUrls.last, Uri.parse('https://example.com/2.mp3'));
      expect(_handler.mediaItem.value?.title, 'Track 2');
    });

    _test('previous on the card plays the song before', (tester) async {
      await _start(tester, _songs(3), index: 2);

      unawaited(_handler.skipToPrevious());
      await _settle(tester);

      expect(_state.item?.id, 'media:2');
      expect(_handler.mediaItem.value?.title, 'Track 2');
    });

    _test('step round the list while repeating all', (tester) async {
      await _start(tester, _songs(3), index: 2);
      expect(_buttons, isNot(contains(MediaAction.skipToNext)));

      _controller.setRepeat(RepeatMode.all);
      await _settle(tester);

      expect(_buttons, contains(MediaAction.skipToNext));
      unawaited(_handler.skipToNext());
      await _settle(tester);
      expect(_state.item?.id, 'media:1');
    });
  });

  group('Play, pause and stop on the card', () {
    _test('show pause while playing and play when paused', (tester) async {
      await _start(tester, _songs(3));
      expect(_buttons, contains(MediaAction.pause));

      await _handler.pause();
      _player.emit(false, ProcessingState.ready);
      await _settle(tester);

      expect(_buttons, contains(MediaAction.play));
      expect(_buttons, isNot(contains(MediaAction.pause)));
    });

    _test('pause pauses', (tester) async {
      await _start(tester, _songs(3));

      await _handler.pause();

      expect(_player.pauses, 1);
      expect(_state.status, PlaybackStatus.paused);
    });

    _test('play carries on after a pause', (tester) async {
      await _start(tester, _songs(3));
      await _handler.pause();
      final playsBefore = _player.plays;

      unawaited(_handler.play());
      await _settle(tester);
      expect(_player.plays, playsBefore + 1);

      // The player says so itself once it is under way.
      _player.emit(true, ProcessingState.ready);
      await _settle(tester);
      expect(_state.status, PlaybackStatus.playing);
    });

    _test('play while already playing does not pause it', (tester) async {
      await _start(tester, _songs(3));

      unawaited(_handler.play());
      await _settle(tester);

      expect(_player.pauses, 0);
      expect(_state.status, PlaybackStatus.playing);
    });

    _test('pause while loading does not give up on it', (tester) async {
      unawaited(_controller.play(_song(1), queue: _songs(3), queueIndex: 0));
      await _settle(tester);
      expect(_state.status, PlaybackStatus.loading);

      await _handler.pause();

      expect(_state.item?.id, 'media:1');
      expect(_state.status, PlaybackStatus.loading);
    });

    _test('stop stops, and takes the card down', (tester) async {
      await _start(tester, _songs(3));

      // Not awaited: the base handler's stop() waits on a stream, which a test's
      // fake clock never delivers.
      unawaited(_handler.stop());
      await _settle(tester);

      expect(_state.item, isNull);
      expect(_player.stops, greaterThan(0));
      expect(
        _handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
    });

    _test('something that has ended shows play, not pause', (tester) async {
      await _start(tester, const [_station]);

      // just_audio leaves `playing` true at the end of a track.
      _player.emit(true, ProcessingState.completed);
      await _settle(tester);

      expect(_buttons, contains(MediaAction.play));
      expect(_handler.playbackState.value.playing, isFalse);
    });
  });

  group('Seeking from the card', () {
    _test('a seek goes to the player', (tester) async {
      final seeks = <Duration>[];
      final handler = RadioAudioHandler()
        ..attach(
          _FakeJustAudio(),
          LockScreenActions(
            play: () async {},
            pause: () async {},
            stop: () async {},
            skipToNext: () async {},
            skipToPrevious: () async {},
            seek: (position) async => seeks.add(position),
            seekBy: (offset) async => seeks.add(offset),
          ),
        );
      addTearDown(handler.detach);

      await handler.seek(const Duration(seconds: 42));
      handler.showItem(_song(1));
      await handler.fastForward();
      await handler.rewind();

      expect(seeks, [
        const Duration(seconds: 42),
        const Duration(seconds: 10),
        const Duration(seconds: -10),
      ]);
    });

    _test('a live station cannot be jumped about in', (tester) async {
      final seeks = <Duration>[];
      final handler = RadioAudioHandler()
        ..attach(
          _FakeJustAudio(),
          LockScreenActions(
            play: () async {},
            pause: () async {},
            stop: () async {},
            skipToNext: () async {},
            skipToPrevious: () async {},
            seek: (position) async => seeks.add(position),
            seekBy: (offset) async => seeks.add(offset),
          ),
        );
      addTearDown(handler.detach);
      handler.showItem(_station);

      await handler.fastForward();
      await handler.rewind();

      expect(seeks, isEmpty);
    });
  });
}
