import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/audio_visualizer.dart';
import 'audio_player_controller.dart';
import 'shared_preferences_provider.dart';

const _kAskedAudioLevelsKey = 'asked_audio_levels_permission';

/// Turns the loudness the phone reports for each band into 0 to 1, against how
/// loud that band has lately been — so the bars use their full height whether
/// the music is quiet or loud, and the bass does not drown the treble.
class BandLevels {
  BandLevels([int count = AudioVisualizer.bands])
    : _peaks = List.filled(count, _floor);

  /// A band is never measured against less than this, however quiet it has been,
  /// so a hiss between songs shows as small bars and is not blown up to full
  /// height.
  static const _floor = 4.0;

  /// How much of a band's recent peak it keeps each time: about two seconds'
  /// memory at 20 readings a second.
  static const _keep = 0.985;

  /// Under this, in every band, a reading is silence.
  static const _silence = 1.0;

  final List<double> _peaks;

  /// Whether every band of [raw] is silent.
  static bool isSilent(List<double> raw) =>
      raw.every((level) => level < _silence);

  List<double> normalize(List<double> raw) {
    return [
      for (var i = 0; i < _peaks.length; i++)
        () {
          final level = i < raw.length ? raw[i] : 0.0;
          _peaks[i] = math.max(math.max(level, _peaks[i] * _keep), _floor);
          return (level / _peaks[i]).clamp(0.0, 1.0);
        }(),
    ];
  }
}

/// The reader of the sound — null anywhere but Android, which is the only place
/// there is one.
final audioVisualizerProvider = Provider<AudioVisualizer?>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? const AudioVisualizer()
      : null,
);

/// How loud each band of what is playing is, 0 to 1, a few times a second — or
/// null when the bars cannot follow the music and should just dance: it is not
/// playing, this is not Android, the person said no to the permission, the phone
/// would not let the app listen, or all that has come back is silence.
class AudioLevelsController extends Notifier<List<double>?> {
  /// This many readings in a row of silence (5 seconds' worth) and the bars
  /// stop trusting the reading and dance until there is sound again.
  static const _silentReadings = 100;

  /// How many readings in a row have been silence.
  var _silent = 0;

  @override
  List<double>? build() {
    final visualizer = ref.watch(audioVisualizerProvider);
    final hasSound = ref.watch(audioPlayerControllerProvider.select(_hasSound));
    _silent = 0;
    if (visualizer == null || !hasSound) return null;

    final listening = _Listening(
      visualizer,
      ref.read(audioPlayerControllerProvider.notifier),
    );
    ref.onDispose(listening.dispose);
    unawaited(listening.begin(_onLevels));
    return null;
  }

  void _onLevels(List<double>? levels, {required bool silent}) {
    if (!ref.mounted) return;
    _silent = silent ? _silent + 1 : 0;
    state = _silent >= _silentReadings ? null : levels;
  }

  /// Asks to listen to the sound — once only, ever, so a no is never nagged
  /// about: the bars then just dance, as they do on a phone that cannot be
  /// asked. Does nothing if it is already allowed.
  Future<void> askOnce() async {
    final visualizer = ref.read(audioVisualizerProvider);
    if (visualizer == null || await visualizer.hasPermission()) return;

    final preferences = ref.read(sharedPreferencesProvider);
    if (preferences.getBool(_kAskedAudioLevelsKey) ?? false) return;
    await preferences.setBool(_kAskedAudioLevelsKey, true);

    if (await visualizer.requestPermission() && ref.mounted) {
      // Now it can listen: build again, which starts it.
      ref.invalidateSelf();
    }
  }

  static bool _hasSound(PlaybackState playback) =>
      playback.status == PlaybackStatus.playing &&
      playback.item != null &&
      // A video link plays in its own embedded player, not ours.
      playback.item!.embed == null;
}

/// One run of listening: the visualizer, started on the player's audio session
/// (and again whenever that changes), and the readings it sends.
class _Listening {
  _Listening(this._visualizer, this._player);

  final AudioVisualizer _visualizer;
  final AudioPlayerController _player;
  final _normalizer = BandLevels();
  StreamSubscription<List<double>>? _levels;
  StreamSubscription<int?>? _session;
  var _disposed = false;

  Future<void> begin(
    void Function(List<double>? levels, {required bool silent}) onLevels,
  ) async {
    if (!await _visualizer.hasPermission() || _disposed) return;

    _levels = _visualizer.levels.listen(
      (raw) => onLevels(
        _normalizer.normalize(raw),
        silent: BandLevels.isSilent(raw),
      ),
      onError: (Object error) => debugPrint('Audio levels failed: $error'),
    );
    _session = _player.androidAudioSessionIdStream.listen((id) {
      if (id != null) unawaited(_visualizer.start(id));
    });
  }

  void dispose() {
    _disposed = true;
    _levels?.cancel();
    _session?.cancel();
    unawaited(_visualizer.stop());
  }
}

final audioLevelsProvider =
    NotifierProvider<AudioLevelsController, List<double>?>(
      AudioLevelsController.new,
    );
