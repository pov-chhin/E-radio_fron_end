import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../themes/app_colors.dart';
import '../../../core/supports/adjacent_station.dart';
import '../../../core/supports/format_duration.dart';
import '../../../core/supports/require_sign_in.dart';
import '../../themes/theme_ext.dart';
import '../../../core/supports/play_meta.dart';
import '../../../data/models/apsara_station.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/player/embedded_video.dart';
import '../../widgets/player/episode_sections.dart';
import '../../widgets/player/song_play_settings_sheet.dart';
import '../../widgets/player/station_player.dart';
import '../../widgets/shared/default_station_art.dart';
import '../../widgets/shared/full_artwork.dart';
import '../../widgets/shared/periodic_marquee_text.dart';
import '../../widgets/shared/playing_indicator.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/audio_levels_provider.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../providers/station_provider.dart';

/// Room under the controls (the design's 44, which also clears the home bar).
const _bottomPadding = 44.0;

class NowPlayingView extends ConsumerWidget {
  const NowPlayingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playback = ref.watch(audioPlayerControllerProvider);
    final item = playback.item;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.nowPlaying)),
        body: Center(child: Text(l10n.noRecentlyPlayed)),
      );
    }

    // Apsara FM97 and FM99 know what is on air, and have a player of their own.
    final apsara = ApsaraStation.fromItem(item);
    if (apsara != null) {
      return StationPlayer(item: item, playback: playback, station: apsara);
    }

    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status-bar icons follow the theme, same as the rest of the app — this
      // screen used to hardcode a light page and dark icons whatever the
      // theme was, which left it the one screen that didn't turn dark.
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          toolbarHeight: 60,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: colors.surface,
          foregroundColor: colors.onSurface,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/explore'),
          ),
          // Plain: one line, cut off with "…" and never sliding. (The title on
          // the picture is the one that slides.)
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 20,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [const _PlayerActionsButton(), const SizedBox(width: 8)],
        ),
        body: item.embed != null
            ? _EmbedBody(item: item)
            : hasEpisodeSections(item)
            ? _PodcastBody(item: item, playback: playback)
            : _PlayerBody(item: item, playback: playback),
      ),
    );
  }
}

/// The picture and the controls under it, filling the screen.
class _PlayerBody extends StatelessWidget {
  const _PlayerBody({required this.item, required this.playback});

  final NowPlayingItem item;
  final PlaybackState playback;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // As wide as the screen and as tall as the design's 390×574 makes it.
        // On a short screen the picture gives way so the controls keep their
        // room.
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              key: const Key('nowPlayingArtwork'),
              width: double.infinity,
              height: math.min(
                constraints.maxWidth / FullArtwork.aspectRatio,
                constraints.maxHeight,
              ),
              child: _ArtworkPanel(
                item: item,
                playing: playback.status == PlaybackStatus.playing,
              ),
            ),
          ),
        ),
        _PlaybackPanel(item: item, playback: playback),
      ],
    );
  }
}

/// How tall [_PlaybackPanel] is at the normal text size: the seek bar, the
/// controls and the room under them.
const _playbackPanelHeight = 160.0;

/// A podcast episode: the picture and the controls, then "About the episode" and
/// the other episodes right under them, all on one page that scrolls. On a short
/// phone the picture still gives way so the controls stay on the first screen.
class _PodcastBody extends StatelessWidget {
  const _PodcastBody({required this.item, required this.playback});

  final NowPlayingItem item;
  final PlaybackState playback;

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(
      _bottomPadding,
      MediaQuery.paddingOf(context).bottom,
    );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              // The picture and controls at their natural size, or the screen
              // if that is shorter.
              height: math.min(
                constraints.maxHeight,
                constraints.maxWidth / FullArtwork.aspectRatio +
                    _playbackPanelHeight,
              ),
              child: _PlayerBody(item: item, playback: playback),
            ),
            EpisodeSections(item: item, bottomPadding: bottom),
          ],
        ),
      ),
    );
  }
}

/// The picture, with the LIVE badge, title and heart on its foot, and — while
/// [playing] — the equalizer bars in a corner.
class _ArtworkPanel extends StatelessWidget {
  const _ArtworkPanel({required this.item, required this.playing});

  final NowPlayingItem item;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final meta = playMetaLine(
      item,
      AppLocalizations.of(context)!,
      Localizations.localeOf(context).toString(),
    );
    final url = item.artworkUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null)
          FullArtwork(url: url)
        else
          const DefaultStationArt(padding: 64),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
                Color(0xB3000000),
              ],
              stops: [0, .58, 1],
            ),
          ),
        ),
        if (playing)
          const Positioned(
            key: Key('nowPlayingWave'),
            left: 20,
            top: 12,
            child: _WaveChip(),
          ),
        Positioned(
          left: 20,
          right: 22,
          bottom: 11,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.isLive) ...[
                      const _LiveBadge(),
                      const SizedBox(height: 13),
                    ],
                    PeriodicMarqueeText(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.pageBackground,
                        fontSize: 20,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // The heart, with the share button under it — and, for a song,
              // the settings for playing songs under that.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FavoriteButton(item: item, onArtwork: true, height: 32),
                  _ShareButton(item: item, onArtwork: true),
                  if (item.isSong) const _SettingsButton(onArtwork: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The equalizer bars, bare, in the picture's corner. This is where the person
/// is asked, once, to let the bars follow the sound — they are in front of the
/// bars when the question comes.
class _WaveChip extends ConsumerStatefulWidget {
  const _WaveChip();

  @override
  ConsumerState<_WaveChip> createState() => _WaveChipState();
}

class _WaveChipState extends ConsumerState<_WaveChip> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(audioLevelsProvider.notifier).askOnce());
    });
  }

  @override
  Widget build(BuildContext context) {
    return const PlayingIndicator(width: 40, height: 22);
  }
}

/// White icons over the picture get this shadow so they stay readable on a
/// light one.
const _onArtworkShadows = [
  Shadow(color: Color(0x550F172A), blurRadius: 4, offset: Offset(0, 2)),
];

/// The heart. [onArtwork] draws it white with a shadow, for over the picture;
/// otherwise it takes the page's text colour. [height] is the room it takes —
/// more than the icon, by default, to sit level with the title beside it.
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({
    required this.item,
    required this.onArtwork,
    this.height = 50,
  });

  final NowPlayingItem item;
  final bool onArtwork;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).contains(item.id);
    return SizedBox(
      width: 36,
      height: height,
      child: Align(
        alignment: Alignment.topCenter,
        child: IconButton(
          tooltip: isFavorite
              ? AppLocalizations.of(context)!.removeFromFavorites
              : AppLocalizations.of(context)!.addToFavorites,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints.tightFor(width: 36, height: 32),
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite
                ? AppColors.primary
                : onArtwork
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
            size: 24,
            shadows: onArtwork ? _onArtworkShadows : null,
          ),
          onPressed: () => requireSignIn(
            context,
            ref,
            () => ref.read(favoritesProvider.notifier).toggle(item.id),
          ),
        ),
      ),
    );
  }
}

/// Opens the system share sheet for what is playing — the same text the ⋮
/// menu's Share sends. [onArtwork] is as for [_FavoriteButton], whose size it
/// shares so the two stack evenly.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.item, required this.onArtwork});

  final NowPlayingItem item;
  final bool onArtwork;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 32,
      child: IconButton(
        tooltip: AppLocalizations.of(context)!.share,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints.tightFor(width: 36, height: 32),
        icon: Icon(
          Icons.share_outlined,
          color: onArtwork
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          size: 24,
          shadows: onArtwork ? _onArtworkShadows : null,
        ),
        onPressed: () =>
            SharePlus.instance.share(ShareParams(text: item.title)),
      ),
    );
  }
}

/// Opens the song play settings (shuffle, repeat) — shown only for a song.
/// [onArtwork] and the size are as for [_ShareButton], which it stacks under.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onArtwork});

  final bool onArtwork;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 32,
      child: IconButton(
        tooltip: AppLocalizations.of(context)!.settings,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints.tightFor(width: 36, height: 32),
        icon: Icon(
          Icons.settings_outlined,
          color: onArtwork
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          size: 24,
          shadows: onArtwork ? _onArtworkShadows : null,
        ),
        onPressed: () => showSongPlaySettings(context),
      ),
    );
  }
}

/// A Facebook video link: Facebook's player where the picture would be, with
/// the title and heart under it. It is paused and sought with the player's own
/// controls.
class _EmbedBody extends StatelessWidget {
  const _EmbedBody({required this.item});

  final NowPlayingItem item;

  @override
  Widget build(BuildContext context) {
    final details = _EmbedDetails(item: item);
    final bottom = math.max(
      _bottomPadding,
      MediaQuery.paddingOf(context).bottom,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // Keyed by item so the next song of the list gets a fresh player.
        children: [
          EmbeddedVideo(key: ValueKey(item.id), item: item),
          details,
        ],
      ),
    );
  }
}

/// The title, view count and date, and the heart.
class _EmbedDetails extends StatelessWidget {
  const _EmbedDetails({required this.item});

  final NowPlayingItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final meta = playMetaLine(
      item,
      AppLocalizations.of(context)!,
      Localizations.localeOf(context).toString(),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PeriodicMarqueeText(
                  item.title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          _FavoriteButton(item: item, onArtwork: false),
        ],
      ),
    );
  }
}

/// The seek bar and the controls, on the page colour under the picture.
class _PlaybackPanel extends StatelessWidget {
  const _PlaybackPanel({required this.item, required this.playback});

  final NowPlayingItem item;
  final PlaybackState playback;

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(
      _bottomPadding,
      MediaQuery.paddingOf(context).bottom,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 9, 20, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.isLive) const _LiveProgress() else const _SeekBar(),
          const SizedBox(height: 8),
          _Controls(item: item, playback: playback),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(80),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: Colors.white, size: 4),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The ⋮ in the top bar: opens the list of what is playing, each row with its
/// own ⋮ for the favorite, comments, bookmark, reminder and share.
class _PlayerActionsButton extends StatelessWidget {
  const _PlayerActionsButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context)!.moreOptions,
      icon: const Icon(Icons.more_vert_rounded, size: 24),
      onPressed: () => context.push('/play-list'),
    );
  }
}

class _LiveProgress extends ConsumerWidget {
  const _LiveProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    return StreamBuilder<Duration>(
      stream: controller.positionStream,
      builder: (context, snapshot) {
        return Column(
          children: [
            const _ProgressTrack(),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDuration(snapshot.data ?? Duration.zero),
                  style: _timeStyle(context),
                ),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SeekBar extends ConsumerWidget {
  const _SeekBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    return StreamBuilder<Duration?>(
      stream: controller.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: controller.positionStream,
          builder: (context, positionSnapshot) {
            final rawPosition = positionSnapshot.data ?? Duration.zero;
            final position = rawPosition > duration ? duration : rawPosition;
            final maxMs = duration.inMilliseconds > 0
                ? duration.inMilliseconds.toDouble()
                : 1.0;
            return Column(
              children: [
                SizedBox(
                  height: 18,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: Theme.of(context).colorScheme.onSurface,
                      inactiveTrackColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      thumbColor: Theme.of(context).colorScheme.onSurface,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: Slider(
                      value: position.inMilliseconds.toDouble().clamp(0, maxMs),
                      max: maxMs,
                      onChanged: duration == Duration.zero
                          ? null
                          : (value) => controller.seek(
                              Duration(milliseconds: value.round()),
                            ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDuration(position), style: _timeStyle(context)),
                    Text(formatDuration(duration), style: _timeStyle(context)),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: colors.onSurface,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// The seek bar's partner. A song gets the music row — back 10 s, previous,
/// play/pause, next, forward 10 s — kept small enough for five buttons on a
/// narrow phone; a podcast episode or a station keeps the
/// roomier row of back 10 s, previous, play/pause, next, forward 10 s.
class _Controls extends ConsumerWidget {
  const _Controls({required this.item, required this.playback});

  final NowPlayingItem item;
  final PlaybackState playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final isSong = item.isSong;

    // A station has no list of its own to step through: back and next go to the
    // station before and after it among all of them, round at either end.
    final isStation = isStationItem(item);
    final stations = isStation
        ? ref.watch(stationsProvider).asData?.value
        : null;
    final previousStation = adjacentStation(stations, item, -1);
    final nextStation = adjacentStation(stations, item, 1);
    final VoidCallback? onPrevious = isStation
        ? (previousStation == null
              ? null
              : () => controller.play(previousStation))
        : (playback.canSkipPrevious ? controller.playPrevious : null);
    final VoidCallback? onNext = isStation
        ? (nextStation == null ? null : () => controller.play(nextStation))
        : (playback.canSkipNext ? controller.playNext : null);

    // Song row: 2 × 40 + 2 × 44 + 60 = 228, which fits the 320 a small phone
    // leaves; the roomy row is the design's 324.
    final side = isSong ? 40.0 : 48.0;
    final sideIcon = isSong ? 24.0 : 30.0;
    final skip = isSong ? 44.0 : 52.0;
    final skipIcon = isSong ? 30.0 : 33.0;
    final playSize = isSong ? 60.0 : 64.0;

    // Material pads every button out to a 48 px tap area; the song row's five
    // buttons only fit at the sizes set above.
    final compact = isSong
        ? IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)
        : null;

    Widget sideButton({
      required IconData icon,
      required VoidCallback? onPressed,
      Color? color,
      String? tooltip,
    }) => IconButton(
      iconSize: sideIcon,
      padding: EdgeInsets.zero,
      style: compact,
      constraints: BoxConstraints.tightFor(width: side, height: side),
      tooltip: tooltip,
      color: color ?? context.mutedText,
      icon: Icon(icon),
      onPressed: onPressed,
    );

    final back10 = sideButton(
      icon: Icons.replay_10_rounded,
      onPressed: item.isLive
          ? null
          : () => controller.seekBy(const Duration(seconds: -10)),
    );
    final forward10 = sideButton(
      icon: Icons.forward_10_rounded,
      onPressed: item.isLive
          ? null
          : () => controller.seekBy(const Duration(seconds: 10)),
    );

    final bar = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        back10,
        IconButton(
          iconSize: skipIcon,
          padding: EdgeInsets.zero,
          style: compact,
          constraints: BoxConstraints.tightFor(width: skip, height: skip),
          color: colors.onSurface,
          icon: Icon(
            isSong ? Icons.skip_previous_rounded : Icons.fast_rewind_rounded,
          ),
          onPressed: onPrevious,
        ),
        if (playback.status == PlaybackStatus.loading)
          SizedBox(
            width: playSize,
            height: playSize,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          )
        else
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              disabledBackgroundColor: const Color(0xFF1E293B),
            ),
            iconSize: isSong ? 40 : 44,
            constraints: BoxConstraints.tightFor(
              width: playSize,
              height: playSize,
            ),
            padding: EdgeInsets.zero,
            color: Colors.white,
            icon: Icon(
              playback.status == PlaybackStatus.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
            onPressed: controller.togglePlayPause,
          ),
        IconButton(
          iconSize: skipIcon,
          padding: EdgeInsets.zero,
          style: compact,
          constraints: BoxConstraints.tightFor(width: skip, height: skip),
          color: colors.onSurface,
          icon: Icon(
            isSong ? Icons.skip_next_rounded : Icons.fast_forward_rounded,
          ),
          onPressed: onNext,
        ),
        forward10,
      ],
    );

    if (!isSong) return SizedBox(width: 324, child: bar);
    // The song row is 228 wide at its smallest; a phone narrower than that
    // leaves less, and the whole row shrinks to fit rather than overflow.
    return LayoutBuilder(
      builder: (context, constraints) {
        const rowWidth = 228.0;
        final width = math.min(constraints.maxWidth, 350.0);
        return SizedBox(
          width: width,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: math.max(width, rowWidth), child: bar),
          ),
        );
      },
    );
  }
}

TextStyle _timeStyle(BuildContext context) => TextStyle(
  color: context.mutedText,
  fontSize: 14,
  height: 1.2,
  fontWeight: FontWeight.w500,
);
