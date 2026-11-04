import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supports/play_meta.dart';
import '../../../core/supports/require_sign_in.dart';
import '../../themes/app_colors.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../shared/artwork_avatar.dart';
import '../shared/periodic_marquee_text.dart';
import '../shared/playing_indicator.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../providers/favorites_provider.dart';

/// Light-pink error tint that stays readable on the brand-violet bar in both
/// the light and dark themes (the theme's own errorContainer goes dark red).
const _errorOnBar = Color(0xFFFFDAD6);

/// The violet player bar shown above the bottom navigation while something is
/// loaded: its picture, name and what it is, a ⊕ to favorite it (red once it
/// is one), and play/pause, with a thin progress line along the bottom edge. Tap
/// opens Now Playing (whose ⋮ opens the Playlist); swipe sideways to stop.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(audioPlayerControllerProvider);
    final item = playback.item;
    if (item == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final isPlaying = playback.status == PlaybackStatus.playing;
    final isLoading = playback.status == PlaybackStatus.loading;
    final isError = playback.status == PlaybackStatus.error;
    final subtitle = isError
        ? l10n.streamUnavailable
        : _subtitleFor(item, l10n, Localizations.localeOf(context).toString());

    return Dismissible(
      key: const ValueKey('mini-player'),
      onDismissed: (_) =>
          ref.read(audioPlayerControllerProvider.notifier).stop(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0F172A),
                offset: Offset(0, 6),
                blurRadius: 10,
              ),
            ],
          ),
          child: Material(
            color: AppColors.brand400,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/now-playing'),
              child: SizedBox(
                height: 68,
                // The title and subtitle are sized to exactly fill the 48px
                // this bar gives them (24 + 4 + 20); a device with a larger
                // system font size would push that over and overflow the
                // fixed-height bar, so — like a nav bar or tab bar — this one
                // ignores the font-size setting and stays pixel-precise.
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.noScaling),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            _Artwork(url: item.artworkUrl, playing: isPlaying),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PeriodicMarqueeText(
                                    item.title,
                                    style: const TextStyle(
                                      color: AppColors.pageBackground,
                                      fontSize: 16,
                                      height: 24 / 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isError
                                            ? _errorOnBar
                                            : const Color(0xFFCBD5E1),
                                        fontSize: 14,
                                        height: 20 / 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _FavoriteBarButton(item: item),
                            const SizedBox(width: 16),
                            if (isLoading)
                              // Tappable — same as the play/pause button — so
                              // a stream that's stuck resolving or buffering
                              // isn't a dead end with no way out.
                              IconButton(
                                tooltip: l10n.stop,
                                iconSize: 24,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 24,
                                  height: 24,
                                ),
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => ref
                                    .read(
                                      audioPlayerControllerProvider.notifier,
                                    )
                                    .togglePlayPause(),
                                icon: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else
                              _BarButton(
                                icon: isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                tooltip: isPlaying ? l10n.pause : l10n.play,
                                onPressed: () => ref
                                    .read(
                                      audioPlayerControllerProvider.notifier,
                                    )
                                    .togglePlayPause(),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _ProgressLine(live: item.isLive),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "News • Live" for a live station with a tag, "Live" without one, or just
  /// the subtitle for on-demand content.
  static String _subtitleFor(
    NowPlayingItem item,
    AppLocalizations l10n,
    String locale,
  ) => [
    item.subtitle,
    if (item.isLive) l10n.live,
    playMetaLine(item, l10n, locale, short: true),
  ].where((part) => part != null && part.isNotEmpty).join(' • ');
}

/// The red of a favorite — the same red as the LIVE badge.
const _favoriteRed = Color(0xFFEF4444);

/// The ⊕ on the bar: adds what is playing to the favorites (signed-in only), or
/// takes it out. A white outline until it is a favorite, then it turns red.
class _FavoriteBarButton extends ConsumerWidget {
  const _FavoriteBarButton({required this.item});

  final NowPlayingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isFavorite = ref.watch(favoritesProvider).contains(item.id);
    return IconButton(
      tooltip: isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
      iconSize: 24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      color: Colors.white,
      icon: isFavorite
          ? const _RedPlus()
          : const Icon(Icons.add_circle_outline_rounded),
      onPressed: () => requireSignIn(
        context,
        ref,
        () => ref.read(favoritesProvider.notifier).toggle(item.id),
      ),
    );
  }
}

/// The ⊕ in red: a red disc with a white rim and a white plus, the same size as
/// the outline. A thin red line alone is no brighter than the violet it sits
/// on, and would hardly show.
class _RedPlus extends StatelessWidget {
  const _RedPlus();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('favoriteRed'),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _favoriteRed,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
    );
  }
}

/// A 24px white icon with no extra tap padding, as the bar draws them.
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      color: Colors.white,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

/// The 44px rounded picture; while playing, a little sound-wave sits on it.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.url, required this.playing});

  final String? url;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ArtworkAvatar(imageUrl: url, size: 44, cornerRadius: 10),
          // Sits right on the picture, so not in the picture's own colours.
          if (playing)
            const PlayingIndicator(
              width: 28.55,
              height: 7.9,
              coverColors: false,
            ),
        ],
      ),
    );
  }
}

/// A 2px line along the bottom of the bar: a faint track, and — for on-demand
/// content — a white stretch showing how far through it is. A live stream has
/// no end, so it's just the track.
class _ProgressLine extends ConsumerWidget {
  const _ProgressLine({required this.live});

  final bool live;

  static const _track = Color(0x4DE5E7EB);

  Widget _line(double? fraction) => SizedBox(
    height: 2,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _track),
        if (fraction != null)
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (live) return _line(null);

    final controller = ref.read(audioPlayerControllerProvider.notifier);
    return StreamBuilder<Duration?>(
      stream: controller.durationStream,
      builder: (context, durationSnapshot) => StreamBuilder<Duration>(
        stream: controller.positionStream,
        builder: (context, positionSnapshot) {
          final total = durationSnapshot.data?.inMilliseconds ?? 0;
          final position = positionSnapshot.data?.inMilliseconds ?? 0;
          return _line(total <= 0 ? 0 : (position / total).clamp(0.0, 1.0));
        },
      ),
    );
  }
}
