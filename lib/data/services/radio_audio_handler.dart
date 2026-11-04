import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/now_playing_item.dart';

/// What the lock screen, the notification and a headset's buttons can ask of
/// the player. They all go to the app's own controller, which knows the list
/// that is playing — the system only ever sees one item at a time.
class LockScreenActions {
  const LockScreenActions({
    required this.play,
    required this.pause,
    required this.stop,
    required this.skipToNext,
    required this.skipToPrevious,
    required this.seek,
    required this.seekBy,
  });

  final Future<void> Function() play;
  final Future<void> Function() pause;
  final Future<void> Function() stop;
  final Future<void> Function() skipToNext;
  final Future<void> Function() skipToPrevious;
  final Future<void> Function(Duration position) seek;
  final Future<void> Function(Duration offset) seekBy;
}

/// The player as the system sees it: the media card on the lock screen and in
/// the notification shade, and the headset and Bluetooth buttons.
///
/// The system draws that card itself; all the app gives it is what is playing
/// ([showItem]), where it is up to (read off the player), and which buttons to
/// offer — previous and next only while the list has somewhere to go
/// ([updateSkips]).
class RadioAudioHandler extends BaseAudioHandler {
  static const _jump = Duration(seconds: 10);

  AudioPlayer? _player;
  LockScreenActions? _actions;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _canSkipPrevious = false;
  bool _canSkipNext = false;

  /// Starts mirroring [player] to the system and sending its buttons to
  /// [actions].
  void attach(AudioPlayer player, LockScreenActions actions) {
    detach();
    _player = player;
    _actions = actions;
    // Both streams are only a nudge to look at the player again — it does not
    // matter which says so first — and an error on them is the controller's to
    // deal with, not the notification's.
    _subscriptions
      ..add(
        player.playbackEventStream.listen((_) => _publish(), onError: _ignore),
      )
      ..add(
        player.playerStateStream.listen((_) => _publish(), onError: _ignore),
      )
      ..add(player.durationStream.listen(_onDuration, onError: _ignore));
    _publish();
  }

  void detach() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _player = null;
    _actions = null;
  }

  static void _ignore(Object error, StackTrace stackTrace) {}

  /// Puts [item] on the card. Called as it is loaded, so an embedded video —
  /// which never reaches the audio player — never gets one.
  void showItem(NowPlayingItem item) {
    final art = item.artworkUrl == null ? null : Uri.tryParse(item.artworkUrl!);
    final current = mediaItem.value;
    if (current != null &&
        current.id == item.id &&
        current.title == item.title &&
        current.artist == item.subtitle &&
        current.artUri == art &&
        current.isLive == item.isLive) {
      return;
    }
    mediaItem.add(
      MediaItem(
        id: item.id,
        title: item.title,
        artist: item.subtitle,
        artUri: art,
        // A station has no length, so no seek bar; iOS labels it LIVE.
        isLive: item.isLive,
      ),
    );
  }

  /// Whether the list has a song before and after the one playing. Buttons for
  /// a step that would do nothing are left off the card.
  void updateSkips({required bool previous, required bool next}) {
    if (_canSkipPrevious == previous && _canSkipNext == next) return;
    _canSkipPrevious = previous;
    _canSkipNext = next;
    _publish();
  }

  void _onDuration(Duration? duration) {
    final current = mediaItem.value;
    if (current == null || current.isLive == true) return;
    if (current.duration == duration) return;
    mediaItem.add(current.copyWith(duration: duration));
  }

  static const _processingStates = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };

  void _publish() {
    final player = _player;
    if (player == null) return;
    final processing = player.processingState;
    // just_audio leaves `playing` true once a track has ended; to the system
    // that is paused.
    final playing =
        player.playing &&
        processing != ProcessingState.idle &&
        processing != ProcessingState.completed;
    final controls = [
      if (_canSkipPrevious) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
      if (_canSkipNext) MediaControl.skipToNext,
    ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.fastForward,
          MediaAction.rewind,
        },
        // The compact card has room for three: everything but stop.
        androidCompactActionIndices: [
          for (var i = 0; i < controls.length; i++)
            if (controls[i].action != MediaAction.stop) i,
        ],
        processingState:
            _processingStates[processing] ?? AudioProcessingState.idle,
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }

  @override
  Future<void> play() async => _actions?.play();

  @override
  Future<void> pause() async => _actions?.pause();

  @override
  Future<void> stop() async {
    await _actions?.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async => _actions?.skipToNext();

  @override
  Future<void> skipToPrevious() async => _actions?.skipToPrevious();

  @override
  Future<void> seek(Duration position) async => _actions?.seek(position);

  @override
  Future<void> fastForward() async => _jumpBy(_jump);

  @override
  Future<void> rewind() async => _jumpBy(-_jump);

  /// A live stream has nowhere to jump to.
  Future<void> _jumpBy(Duration offset) async {
    if (mediaItem.value?.isLive == true) return;
    await _actions?.seekBy(offset);
  }
}
