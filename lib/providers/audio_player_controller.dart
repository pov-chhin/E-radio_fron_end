import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../core/router/app_router.dart';
import '../core/supports/notification_permission.dart';
import '../data/services/api_client.dart';
import '../data/services/radio_audio_handler.dart';
import 'audio_handler_provider.dart';
import 'equalizer_provider.dart';
import 'shared_preferences_provider.dart';
import 'recently_played_provider.dart';
import '../data/models/now_playing_item.dart';
import '../data/services/playback_progress_store.dart';
import 'reminder_provider.dart';

enum PlaybackStatus { idle, loading, playing, paused, error }

/// What a song does when it ends: nothing more ([off]), start the list over
/// once its last song is done ([all]), or play the same song again ([one]).
enum RepeatMode { off, all, one }

class PlaybackState {
  const PlaybackState({
    this.item,
    this.status = PlaybackStatus.idle,
    this.errorMessage,
    this.volume = 1.0,
    this.queue = const [],
    this.queueIndex = -1,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
  });

  final NowPlayingItem? item;
  final PlaybackStatus status;
  final String? errorMessage;
  final double volume;

  /// The list [item] was played from (e.g. a category's song list), so
  /// next/previous can step through it. A single standalone item (a station,
  /// or media played with no list context) is just a queue of one.
  final List<NowPlayingItem> queue;
  final int queueIndex;

  /// Shuffle and repeat are the music player's: they are chosen once and kept
  /// from song to song, but only act while a song is playing — a podcast or a
  /// station in between plays as it always did.
  final bool shuffle;
  final RepeatMode repeat;

  RepeatMode get activeRepeat =>
      (item?.isSong ?? false) ? repeat : RepeatMode.off;

  bool get hasNext => queueIndex >= 0 && queueIndex < queue.length - 1;

  bool get hasPrevious => queueIndex > 0;

  /// Next/previous also step round the end of the list while repeating it all.
  bool get canSkipNext =>
      hasNext || (activeRepeat == RepeatMode.all && queue.length > 1);

  bool get canSkipPrevious =>
      hasPrevious || (activeRepeat == RepeatMode.all && queue.length > 1);

  PlaybackState copyWith({
    NowPlayingItem? item,
    PlaybackStatus? status,
    String? errorMessage,
    bool clearError = false,
    double? volume,
    List<NowPlayingItem>? queue,
    int? queueIndex,
    bool? shuffle,
    RepeatMode? repeat,
  }) {
    return PlaybackState(
      item: item ?? this.item,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      volume: volume ?? this.volume,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
    );
  }
}

class AudioPlayerController extends Notifier<PlaybackState> {
  late final AudioPlayer _player;

  /// The lock-screen and notification player, if this run has one.
  RadioAudioHandler? _handler;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<PlaybackEvent>? _playerEventSub;
  Timer? _progressSaveTimer;

  static const _progressSaveInterval = Duration(seconds: 5);
  static const _loadRetryDelay = Duration(milliseconds: 400);
  static const _liveLoadAttempts = 4;

  /// How many times in a row a live stream that fails while playing is loaded
  /// again, counting failures less than [_liveRecoveryWindow] apart as in a row.
  static const _liveRecoveryAttempts = 3;
  static const _liveRecoveryWindow = Duration(seconds: 30);

  /// Bumped by every play() and stop(); a play() that finds it changed has
  /// been superseded and must not touch state or the player any further.
  int _playRequest = 0;

  /// The list as its screen gave it, kept while shuffle has [PlaybackState.queue]
  /// in a random order, so turning shuffle off puts the order back.
  List<NowPlayingItem> _orderedQueue = const [];

  /// Where shuffle gets its randomness — a test swaps in a seeded one.
  @visibleForTesting
  Random shuffleRandom = Random();

  /// The play() request that is putting a source into the player, if any. That
  /// has its own retries, so an error raised meanwhile must not start a second
  /// reload.
  int? _loadingRequest;

  /// Runs from the moment a play() starts loading until the player first
  /// reports playing — the wait the listener sees. Only used to log it.
  Stopwatch? _startupTimer;
  int _liveRecoveries = 0;
  DateTime? _lastLiveRecovery;

  /// The player this controller drives — one for the whole app; a test swaps
  /// in a fake.
  @visibleForTesting
  AudioPlayer createPlayer() => AudioPlayer(
    // The equalizer sits in the player's audio pipeline (Android only — there
    // is none elsewhere). It stays bypassed until the person switches it on.
    audioPipeline: _audioPipeline(),
    // The Android default waits for 2.5 seconds of decoded audio before it
    // starts. Music is served as progressive files with byte-range support,
    // so a shorter first buffer makes a tap sound much sooner. A rebuffer uses
    // a larger threshold to avoid repeatedly stopping on a weak connection.
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        bufferForPlaybackDuration: Duration(milliseconds: 750),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
      ),
      // AVPlayer otherwise deliberately waits for a conservative amount of
      // data. Let it begin as soon as the progressive source is playable.
      darwinLoadControl: DarwinLoadControl(
        automaticallyWaitsToMinimizeStalling: false,
      ),
    ),
  );

  /// The player's Android audio session — what the playing bars listen to. Null
  /// until a source is loaded, and anywhere but Android.
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;

  AudioPipeline? _audioPipeline() {
    final equalizer = ref.read(equalizerEffectProvider);
    return equalizer == null
        ? null
        : AudioPipeline(androidAudioEffects: [equalizer]);
  }

  @override
  PlaybackState build() {
    _player = createPlayer();
    _playerStateSub = _player.playerStateStream.listen(_onPlayerState);
    _playerEventSub = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace _) => _onPlayerError(error),
    );
    // The lock screen and the notification show this player, and every button
    // on them comes back here — previous and next included, since only the app
    // knows the list that is playing.
    final handler = _handler = ref.read(audioHandlerProvider);
    handler?.attach(
      _player,
      LockScreenActions(
        play: resume,
        pause: pause,
        stop: stop,
        skipToNext: playNext,
        skipToPrevious: playPrevious,
        seek: seek,
        seekBy: seekBy,
      ),
    );
    listenSelf((_, next) {
      handler?.updateSkips(
        previous: next.canSkipPrevious,
        next: next.canSkipNext,
      );
    });
    // Leaving the app (or having it killed) is not a pause, but it is the last
    // chance to keep the place.
    final observer = _SaveOnLeave(_saveCurrentProgress);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      handler?.detach();
      WidgetsBinding.instance.removeObserver(observer);
      _playerStateSub?.cancel();
      _playerEventSub?.cancel();
      _progressSaveTimer?.cancel();
      _player.dispose();
    });
    return const PlaybackState();
  }

  /// A live stream can fail part-way through — a dropped connection, or a stall
  /// long enough that the next segment has already left the playlist (a 404).
  /// Left alone the player sits dead on a spinner, so load the stream again,
  /// from the live edge. Gives up after a few failures in quick succession.
  void _onPlayerError(Object error) {
    final item = state.item;
    if (_loadingRequest != null ||
        item == null ||
        !item.isLive ||
        state.status == PlaybackStatus.error) {
      return;
    }

    final now = DateTime.now();
    final last = _lastLiveRecovery;
    _liveRecoveries = last != null && now.difference(last) < _liveRecoveryWindow
        ? _liveRecoveries + 1
        : 1;
    _lastLiveRecovery = now;

    if (_liveRecoveries > _liveRecoveryAttempts) {
      debugPrint(
        '${item.title} keeps failing while playing, giving up: $error',
      );
      state = state.copyWith(
        status: PlaybackStatus.error,
        errorMessage: 'playbackFailed',
      );
      return;
    }

    debugPrint(
      '${item.title} failed while playing ($error), loading it again '
      '($_liveRecoveries/$_liveRecoveryAttempts)',
    );
    unawaited(
      _play(
        item,
        queue: state.queue,
        queueIndex: state.queueIndex,
        reload: true,
      ),
    );
  }

  void _onPlayerState(PlayerState playerState) {
    if (state.status == PlaybackStatus.error) return;
    // just_audio leaves `playing` true when an item ends, so `completed` has to
    // be told apart here or it would be taken for still playing.
    if (playerState.playing &&
        playerState.processingState != ProcessingState.completed) {
      state = state.copyWith(status: PlaybackStatus.playing, clearError: true);
      final startup = _startupTimer;
      if (startup != null) {
        debugPrint(
          '${state.item?.title} started playing '
          '${startup.elapsedMilliseconds} ms after it was requested',
        );
        _startupTimer = null;
      }
      // Playback can be started from outside the app too (the notification,
      // a headset button): keep the place from then on.
      final item = state.item;
      if (item != null && !item.isLive && _progressSaveTimer == null) {
        _startProgressTracking(item);
      }
      return;
    }
    switch (playerState.processingState) {
      case ProcessingState.loading:
      case ProcessingState.buffering:
        state = state.copyWith(status: PlaybackStatus.loading);
        break;
      case ProcessingState.idle:
        break;
      case ProcessingState.ready:
        // Ready but not playing while loading is just the load finishing —
        // nothing to keep yet, and the player may still hold the last item.
        final justLoaded = state.status == PlaybackStatus.loading;
        state = state.copyWith(status: PlaybackStatus.paused);
        if (!justLoaded) {
          // Paused from outside the app (the notification, a headset button, a
          // phone call) as often as from inside: keep the place either way.
          _stopProgressTracking();
          _saveCurrentProgress();
        }
        break;
      case ProcessingState.completed:
        final item = state.item;
        // A song that ends moves on to the next in its list. Not while the next
        // is already loading (a repeated event must not skip a song), and never
        // for a live station — an ended stream is a drop, not a finished song.
        final finished =
            item != null &&
            !item.isLive &&
            state.status != PlaybackStatus.loading;
        // Repeat one — or repeat all with nothing else in the list — plays the
        // same song again.
        final repeat = state.activeRepeat;
        final again =
            finished &&
            (repeat == RepeatMode.one ||
                (repeat == RepeatMode.all && state.queue.length <= 1));
        final advance = finished && !again && state.canSkipNext;
        state = state.copyWith(status: PlaybackStatus.paused);
        _stopProgressTracking();
        if (item != null && !item.isLive) _saveProgress(item);
        if (again) {
          unawaited(_playAgain());
        } else if (advance) {
          unawaited(playNext());
        }
        break;
    }
  }

  /// [queue]/[queueIndex] give next/previous something to step through — a
  /// list screen passes the list the user tapped into; a standalone play
  /// (a station, a share link, …) defaults to a queue of just [item].
  Future<void> play(
    NowPlayingItem item, {
    List<NowPlayingItem>? queue,
    int? queueIndex,
  }) {
    var playQueue = queue;
    var playIndex = queueIndex;
    // With shuffle on, a song picked from a new list plays first and the rest
    // follow in random order. The "up next" list hands back the queue that is
    // already in play, which must not be shuffled again.
    if (queue == null || !state.shuffle || !item.isSong) {
      _orderedQueue = const [];
    } else if (queue.length > 1 && !_sameQueue(queue, state.queue)) {
      final at = playIndex != null && playIndex >= 0 && playIndex < queue.length
          ? playIndex
          : queue.indexWhere((e) => e.id == item.id);
      if (at >= 0) {
        _orderedQueue = queue;
        playQueue = _shuffled(queue, at);
        playIndex = 0;
      }
    }
    return _play(item, queue: playQueue, queueIndex: playIndex);
  }

  bool _sameQueue(List<NowPlayingItem> a, List<NowPlayingItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// [queue] with the song at [index] first and the others in random order.
  List<NowPlayingItem> _shuffled(List<NowPlayingItem> queue, int index) {
    final rest = [...queue]..removeAt(index);
    rest.shuffle(shuffleRandom);
    return [queue[index], ...rest];
  }

  /// Shuffle on: the song playing stays first and the rest of the list is put
  /// in random order. Off: the list goes back to the order it came in.
  void toggleShuffle() {
    final on = !state.shuffle;
    final item = state.item;
    var queue = state.queue;
    var index = state.queueIndex;
    if (on) {
      if (item != null &&
          item.isSong &&
          queue.length > 1 &&
          index >= 0 &&
          index < queue.length) {
        _orderedQueue = queue;
        queue = _shuffled(queue, index);
        index = 0;
      }
    } else {
      final restored = _orderedQueue.indexWhere((e) => e.id == item?.id);
      if (restored >= 0) {
        queue = _orderedQueue;
        index = restored;
      }
      _orderedQueue = const [];
    }
    state = state.copyWith(shuffle: on, queue: queue, queueIndex: index);
  }

  /// Off, then repeat the whole list, then repeat this song, then off again.
  void cycleRepeat() => setRepeat(
    RepeatMode.values[(state.repeat.index + 1) % RepeatMode.values.length],
  );

  /// Picks the repeat mode outright — the song settings list all three.
  void setRepeat(RepeatMode mode) {
    state = state.copyWith(repeat: mode);
  }

  /// The song that just ended, from the start.
  Future<void> _playAgain() async {
    final request = _playRequest;
    await _player.seek(Duration.zero);
    if (request != _playRequest) return;
    // play() only returns once playback pauses again, so it is not waited on.
    unawaited(_player.play());
    final item = state.item;
    state = state.copyWith(status: PlaybackStatus.playing);
    if (item != null) _startProgressTracking(item);
  }

  /// [reload] loads [item] again even though it is already the one playing.
  Future<void> _play(
    NowPlayingItem item, {
    List<NowPlayingItem>? queue,
    int? queueIndex,
    bool reload = false,
  }) async {
    final resolvedQueue = queue ?? [item];
    final resolvedIndex = queueIndex ?? 0;

    if (!reload &&
        state.item?.id == item.id &&
        (state.status == PlaybackStatus.playing ||
            state.status == PlaybackStatus.loading)) {
      state = state.copyWith(queue: resolvedQueue, queueIndex: resolvedIndex);
      return;
    }

    final previous = state.item;
    final request = ++_playRequest;
    bool superseded() => request != _playRequest;
    final timer = _startupTimer = Stopwatch()..start();

    _stopProgressTracking();
    state = PlaybackState(
      item: item,
      status: PlaybackStatus.loading,
      queue: resolvedQueue,
      queueIndex: resolvedIndex,
      shuffle: state.shuffle,
      repeat: state.repeat,
    );
    try {
      // Moving on from another on-demand item part-way: keep its place first,
      // while the player still holds it.
      if (previous != null && previous.id != item.id && !previous.isLive) {
        await _saveProgress(previous);
        if (superseded()) return;
      }
      // A YouTube or Facebook link isn't audio just_audio can load: it plays in
      // the site's embedded player on Now Playing. Silence whatever the audio
      // player holds so it doesn't keep going behind the video.
      if (item.embed != null) {
        await _player.stop();
        if (superseded()) return;
        // The embedded player reports playing once it is on screen.
        state = state.copyWith(status: PlaybackStatus.paused);
        _recordPlay(item);
        _openNowPlaying();
        return;
      }
      // The app normally asks at launch. If playback wins that race, do not
      // hold the audio network request behind a system permission dialog.
      final prefs = ref.read(sharedPreferencesProvider);
      if (!notificationPermissionWasAsked(prefs)) {
        try {
          unawaited(
            askNotificationPermissionOnce(
              prefs,
              ref.read(reminderServiceProvider),
            ),
          );
        } catch (error) {
          // Playback also runs where notifications are unavailable and must
          // never depend on that optional integration.
          debugPrint('Notification permission unavailable: $error');
        }
      }
      // Starts from the address the item already carries — the list it came
      // from has the same stream_url — so a song doesn't wait on a round trip
      // to the server first. If that address turns out to be out of date (a
      // cached list), the retry below asks the server for the current one.
      var resolvedItem = item;
      // A live station has no place to resume, and a song always starts over —
      // only other on-demand media (a podcast episode) picks up where it was.
      final initialPosition = resolvedItem.isLive || resolvedItem.isSong
          ? null
          : await _fetchSavedPosition(resolvedItem.id);
      if (superseded()) return;
      Future<void> load() async {
        // On the lock screen and in the notification before it is playing, so
        // the card is there while it loads.
        _handler?.showItem(resolvedItem);
        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(resolvedItem.streamUrl)),
          initialPosition: initialPosition,
        );
      }

      // Live HLS origins can briefly return an empty/stale playlist while a
      // segment rolls over. One retry 400 ms later is too quick for an
      // eight-second playlist such as Apsara FM97, so give live streams a few
      // progressively spaced attempts. On-demand media keeps the old single
      // retry so a genuinely unavailable file still fails promptly.
      final maxAttempts = resolvedItem.isLive ? _liveLoadAttempts : 2;
      _loadingRequest = request;
      try {
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            await load();
            break;
          } on PlayerException catch (error) {
            if (superseded()) return;
            if (attempt == maxAttempts) rethrow;
            final delay = resolvedItem.isLive
                ? Duration(seconds: 1 << (attempt - 1))
                : _loadRetryDelay;
            debugPrint(
              'Loading ${item.title} failed (attempt $attempt/$maxAttempts), '
              'trying again in ${delay.inMilliseconds} ms: $error',
            );
            await Future<void>.delayed(delay);
            if (superseded()) return;
            resolvedItem = await _resolveLatestMediaUrl(resolvedItem);
            if (superseded()) return;
            state = state.copyWith(item: resolvedItem);
          }
        }
      } finally {
        if (_loadingRequest == request) _loadingRequest = null;
      }
      if (superseded()) return;
      debugPrint(
        '${resolvedItem.title} loaded in ${timer.elapsedMilliseconds} ms',
      );
      // Before the await: play() only completes when playback pauses or
      // ends, so anything after it would happen far too late — the view
      // counted, the history written, the place saved as it plays.
      _recordPlay(resolvedItem);
      if (!resolvedItem.isLive) _startProgressTracking(resolvedItem);
      await _player.play();
    } catch (error, stackTrace) {
      // A newer play() or a stop() cutting in throws "Loading interrupted"
      // here; that's not a failure of this item and mustn't overwrite the
      // newer state.
      if (superseded()) return;
      _stopProgressTracking();
      debugPrint(
        'Playback failed for ${item.title} (${item.streamUrl}): $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(
        item: item,
        status: PlaybackStatus.error,
        errorMessage: 'playbackFailed',
      );
    }
  }

  /// Counts [item] as played: the view count, and the recently-played history.
  void _recordPlay(NowPlayingItem item) {
    if (item.contentType == 'media') _countView(item);
    ref.read(recentlyPlayedProvider.notifier).recordPlay(item.id);
    ref
        .read(recentlyPlayedAtProvider.notifier)
        .recordPlayedAt(item.id, retainedIds: ref.read(recentlyPlayedProvider));
  }

  /// An embedded video only plays on the Now Playing page, so playing one
  /// opens it — unless it is already the page on top.
  void _openNowPlaying() {
    final router = ref.read(appRouterProvider);
    // `lastOrNull` is the page on top, pushed ones included — unlike the
    // configuration's own uri, which stays that of the page underneath.
    final top = router.routerDelegate.currentConfiguration.lastOrNull;
    if (top?.matchedLocation != '/now-playing') router.push('/now-playing');
  }

  /// The embedded player on Now Playing tells the controller whether the video
  /// is playing, and goes back to false when the page closes (the video stops
  /// with it). [itemId] guards against a late report for an item that has
  /// since been replaced.
  void reportEmbedPlaying(String itemId, bool playing) {
    final item = state.item;
    if (item == null || item.embed == null || item.id != itemId) return;
    final status = playing ? PlaybackStatus.playing : PlaybackStatus.paused;
    if (state.status != status) state = state.copyWith(status: status);
  }

  /// Tells the server this item was played and shows the new total. Best
  /// effort: a failure just leaves the old count on screen.
  Future<void> _countView(NowPlayingItem item) async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .post('/media-contents/${item.contentId}/play', {});
      final count = res is Map ? res['play_count'] as int? : null;
      if (count != null && state.item?.id == item.id) {
        state = state.copyWith(item: state.item!.withPlayCount(count));
      }
    } catch (error) {
      debugPrint('Counting the view failed: $error');
    }
  }

  Future<void> playNext() {
    if (!state.canSkipNext) return Future.value();
    // Past the last song, repeating the whole list starts it over.
    final index = state.hasNext ? state.queueIndex + 1 : 0;
    return _play(state.queue[index], queue: state.queue, queueIndex: index);
  }

  Future<void> playPrevious() {
    if (!state.canSkipPrevious) return Future.value();
    final index = state.hasPrevious
        ? state.queueIndex - 1
        : state.queue.length - 1;
    return _play(state.queue[index], queue: state.queue, queueIndex: index);
  }

  Future<NowPlayingItem> _resolveLatestMediaUrl(NowPlayingItem item) async {
    if (!item.id.startsWith('media:')) return item;

    final mediaId = item.id.substring('media:'.length);
    final response = await ref
        .read(apiClientProvider)
        .get('/media-contents/$mediaId');
    final payload = response is Map ? response['data'] : null;
    final streamUrl = payload is Map ? payload['stream_url'] as String? : null;

    if (streamUrl == null || streamUrl.isEmpty) {
      throw StateError('The media item has no ready stream.');
    }

    return item.withStreamUrl(streamUrl);
  }

  /// The play button on the lock screen and the notification — and a headset's.
  /// Unlike [togglePlayPause], a press while it is already playing or still
  /// loading must not turn into a pause or a give-up.
  Future<void> resume() async {
    if (state.status == PlaybackStatus.paused ||
        state.status == PlaybackStatus.error) {
      await togglePlayPause();
    }
  }

  /// The pause button on the lock screen and the notification.
  Future<void> pause() async {
    if (state.status == PlaybackStatus.playing) await togglePlayPause();
  }

  Future<void> togglePlayPause() async {
    final item = state.item;
    if (item == null) return;
    if (item.embed != null) {
      // The video is paused and resumed with the controls on Now Playing.
      _openNowPlaying();
      return;
    }
    if (state.status == PlaybackStatus.playing) {
      await _player.pause();
      state = state.copyWith(status: PlaybackStatus.paused);
      _stopProgressTracking();
      if (!item.isLive) _saveProgress(item);
    } else if (state.status == PlaybackStatus.paused) {
      await _player.play();
      state = state.copyWith(status: PlaybackStatus.playing);
      if (!item.isLive) _startProgressTracking(item);
    } else if (state.status == PlaybackStatus.error) {
      await play(item);
    } else if (state.status == PlaybackStatus.loading) {
      // Tapped while still resolving the stream or buffering — there's
      // nothing to toggle yet, so treat it as "give up waiting" rather than
      // doing nothing, which otherwise leaves the player looking stuck.
      await stop();
    }
  }

  Future<void> stop() async {
    final item = state.item;
    _stopProgressTracking();
    _playRequest++;
    _startupTimer = null;
    // Cleared before the awaits so the mini player's swipe-to-dismiss (which
    // calls this from onDismissed) is out of the tree by the next frame.
    _orderedQueue = const [];
    state = PlaybackState(shuffle: state.shuffle, repeat: state.repeat);
    if (item != null && !item.isLive) await _saveProgress(item);
    await _player.stop();
  }

  void _startProgressTracking(NowPlayingItem item) {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer.periodic(
      _progressSaveInterval,
      (_) => _saveProgress(item),
    );
  }

  void _stopProgressTracking() {
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
  }

  /// Best-effort — a failed read just means playback starts from 0 instead
  /// of resuming, never a reason to block playback.
  Future<Duration?> _fetchSavedPosition(String itemId) async {
    if (!itemId.startsWith('media:')) return null;
    try {
      return await ref.read(playbackProgressStoreProvider).fetch(itemId);
    } catch (_) {
      return null;
    }
  }

  /// Saves the place in whatever is loaded, if it is on demand.
  void _saveCurrentProgress() {
    final item = state.item;
    if (item != null && !item.isLive) _saveProgress(item);
  }

  /// Best-effort — a missed save just means resuming a little earlier next
  /// time, never a reason to surface an error to the user.
  Future<void> _saveProgress(NowPlayingItem item) async {
    // An embedded video's place isn't the audio player's (which is stopped),
    // and a song is never resumed, so there is no place worth keeping.
    if (!item.id.startsWith('media:') || item.embed != null || item.isSong) {
      return;
    }
    final position = _player.position;
    if (position == Duration.zero) return;
    try {
      await ref
          .read(playbackProgressStoreProvider)
          .save(item.id, position, _player.duration);
    } catch (_) {
      // Ignored — see doc comment.
    }
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
    state = state.copyWith(volume: volume);
  }

  /// For an on-demand item's seek bar — meaningless for a live station.
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _saveIfNotPlaying();
  }

  Future<void> seekBy(Duration offset) async {
    final target = _player.position + offset;
    final duration = _player.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (duration != null && target > duration ? duration : target);
    await _player.seek(clamped);
    _saveIfNotPlaying();
  }

  /// A seek while playing is caught by the next save; one while paused would
  /// otherwise be forgotten, resuming from where it was paused.
  void _saveIfNotPlaying() {
    if (state.status != PlaybackStatus.playing) _saveCurrentProgress();
  }
}

/// Saves the place when the app goes to the background or is closed.
class _SaveOnLeave with WidgetsBindingObserver {
  _SaveOnLeave(this._save);

  final VoidCallback _save;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _save();
    }
  }
}

final audioPlayerControllerProvider =
    NotifierProvider<AudioPlayerController, PlaybackState>(
      AudioPlayerController.new,
    );
