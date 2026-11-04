import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/services/audio_visualizer.dart';
import 'package:e_radio/providers/audio_levels_provider.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';

const _song = NowPlayingItem(
  id: 'media:7',
  title: 'Evening Mix',
  streamUrl: 'https://example.com/mix.mp3',
  isLive: false,
);

const _playing = PlaybackState(item: _song, status: PlaybackStatus.playing);
const _paused = PlaybackState(item: _song, status: PlaybackStatus.paused);

class _FakePlayer extends AudioPlayerController {
  _FakePlayer(this.initial, this.sessions);

  final PlaybackState initial;
  final Stream<int?> sessions;

  @override
  PlaybackState build() => initial;

  void show(PlaybackState next) => state = next;

  @override
  Stream<int?> get androidAudioSessionIdStream => sessions;
}

/// A phone that can be listened to, or not, and notes what it is asked.
class _FakeVisualizer extends AudioVisualizer {
  _FakeVisualizer({this.allowed = true, this.willAllow = false});

  bool allowed;

  /// What the system's question is answered, if it is asked.
  final bool willAllow;

  final started = <int>[];
  var stops = 0;
  var questions = 0;
  final _levels = StreamController<List<double>>.broadcast();

  void send(List<double> raw) => _levels.add(raw);

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<bool> requestPermission() async {
    questions++;
    allowed = willAllow;
    return willAllow;
  }

  @override
  Future<bool> start(int sessionId) async {
    started.add(sessionId);
    return true;
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Stream<List<double>> get levels => _levels.stream;
}

List<double> _loud([double level = 40]) => List.filled(10, level);

void main() {
  group('BandLevels', () {
    test('the loudest a band has lately been is its full height', () {
      final bands = BandLevels();

      expect(bands.normalize(_loud(40)), everyElement(1.0));
    });

    test('a quieter reading is a share of that', () {
      final bands = BandLevels()..normalize(_loud(40));

      expect(bands.normalize(_loud(20)), everyElement(closeTo(.5, .02)));
    });

    test('each band is measured against its own past', () {
      final bands = BandLevels()
        ..normalize([100, 10, 10, 10, 10, 10, 10, 10, 10, 10]);

      final levels = bands.normalize([50, 10, 10, 10, 10, 10, 10, 10, 10, 10]);

      expect(levels[0], closeTo(.5, .02)); // half the bass it had
      expect(levels[1], closeTo(1, .01)); // all of the treble it had
    });

    test('and the past fades, so a quieter song fills the bars again', () {
      final bands = BandLevels()..normalize(_loud(100));
      for (var i = 0; i < 400; i++) {
        bands.normalize(_loud(0));
      }

      expect(bands.normalize(_loud(10)), everyElement(closeTo(1, .01)));
    });

    test('a hiss is small bars, not blown up to full height', () {
      final levels = BandLevels().normalize(_loud(1));

      expect(levels, everyElement(lessThan(.3)));
    });

    test('keeps to 0 to 1 and to its number of bands', () {
      final levels = BandLevels(4).normalize([500, -20]);

      expect(levels, hasLength(4));
      expect(levels, everyElement(inInclusiveRange(0, 1)));
      expect(levels.sublist(1), everyElement(0)); // none sent means none heard
    });

    test('a reading is silent only if every band is', () {
      expect(BandLevels.isSilent(_loud(0)), isTrue);
      expect(BandLevels.isSilent(_loud(.9)), isTrue);
      expect(BandLevels.isSilent([0, 0, 0, 1, 0, 0, 0, 0, 0, 0]), isFalse);
    });
  });

  group('audioLevelsProvider', () {
    late StreamController<int?> sessions;
    late _FakeVisualizer visualizer;

    setUp(() {
      sessions = StreamController<int?>.broadcast();
      addTearDown(sessions.close);
      visualizer = _FakeVisualizer();
    });

    Future<(ProviderContainer, _FakePlayer)> open({
      PlaybackState playback = _playing,
      AudioVisualizer? Function()? reader,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final player = _FakePlayer(playback, sessions.stream);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          audioVisualizerProvider.overrideWithValue(
            reader == null ? visualizer : reader(),
          ),
          audioPlayerControllerProvider.overrideWith(() => player),
        ],
      );
      addTearDown(container.dispose);
      // Kept alive, as the bars on screen keep it.
      container.listen(audioLevelsProvider, (_, _) {});
      await pumpEventQueue();
      return (container, player);
    }

    List<double>? levelsOf(ProviderContainer container) =>
        container.read(audioLevelsProvider);

    test('has no levels until there is sound to listen to', () async {
      final (container, _) = await open(playback: _paused);
      sessions.add(7);
      await pumpEventQueue();

      expect(visualizer.started, isEmpty);
      expect(levelsOf(container), isNull);
    });

    test('listens to the player\'s audio session while it plays', () async {
      final (container, _) = await open();
      sessions.add(7);
      await pumpEventQueue();
      visualizer.send(_loud(40));
      await pumpEventQueue();

      expect(visualizer.started, [7]);
      expect(levelsOf(container), everyElement(1.0));
    });

    test('and listens again when the session changes', () async {
      await open();
      sessions
        ..add(7)
        ..add(null) // nothing loaded for a moment
        ..add(9);
      await pumpEventQueue();

      expect(visualizer.started, [7, 9]);
    });

    test('stops listening, and has no levels, when it is paused', () async {
      final (container, player) = await open();
      sessions.add(7);
      await pumpEventQueue();
      visualizer.send(_loud(40));
      await pumpEventQueue();
      expect(levelsOf(container), isNotNull);

      player.show(_paused);
      await pumpEventQueue();

      expect(visualizer.stops, 1);
      expect(levelsOf(container), isNull);
    });

    test('without permission it never listens', () async {
      visualizer.allowed = false;
      final (container, _) = await open();
      sessions.add(7);
      await pumpEventQueue();
      visualizer.send(_loud(40));
      await pumpEventQueue();

      expect(visualizer.started, isEmpty);
      expect(levelsOf(container), isNull);
    });

    test('where there is no way to listen it has no levels', () async {
      final (container, _) = await open(reader: () => null);
      sessions.add(7);
      await pumpEventQueue();

      expect(levelsOf(container), isNull);
    });

    test('five seconds of silence and the bars dance instead', () async {
      final (container, _) = await open();
      sessions.add(7);
      await pumpEventQueue();

      for (var i = 0; i < 99; i++) {
        visualizer.send(_loud(0));
        await pumpEventQueue();
      }
      expect(levelsOf(container), isNotNull);

      visualizer.send(_loud(0));
      await pumpEventQueue();
      expect(levelsOf(container), isNull);

      // Until there is sound again.
      visualizer.send(_loud(30));
      await pumpEventQueue();
      expect(levelsOf(container), isNotNull);
    });

    test('is asked for once only, however often it is asked about', () async {
      visualizer.allowed = false;
      final (container, _) = await open();
      final levels = container.read(audioLevelsProvider.notifier);

      await levels.askOnce();
      await levels.askOnce();

      expect(visualizer.questions, 1);
    });

    test('is not asked for when it is already allowed', () async {
      final (container, _) = await open();

      await container.read(audioLevelsProvider.notifier).askOnce();

      expect(visualizer.questions, 0);
    });

    test('starts listening as soon as the answer is yes', () async {
      visualizer = _FakeVisualizer(allowed: false, willAllow: true);
      final (container, _) = await open();
      sessions.add(7);
      await pumpEventQueue();
      expect(visualizer.started, isEmpty);

      await container.read(audioLevelsProvider.notifier).askOnce();
      await pumpEventQueue();
      sessions.add(7);
      await pumpEventQueue();

      expect(visualizer.questions, 1);
      expect(visualizer.started, [7]);
    });

    test('a no is remembered: it is never asked again', () async {
      visualizer = _FakeVisualizer(allowed: false);
      final (container, _) = await open();
      await container.read(audioLevelsProvider.notifier).askOnce();
      expect(visualizer.questions, 1);

      // The next time the app runs, with the same saved answer.
      final preferences = await SharedPreferences.getInstance();
      final again = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          audioVisualizerProvider.overrideWithValue(visualizer),
          audioPlayerControllerProvider.overrideWith(
            () => _FakePlayer(_playing, sessions.stream),
          ),
        ],
      );
      addTearDown(again.dispose);
      await again.read(audioLevelsProvider.notifier).askOnce();

      expect(visualizer.questions, 1);
    });
  });
}
