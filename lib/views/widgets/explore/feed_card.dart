import 'package:flutter/material.dart';
import '../../../core/supports/tap_to_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/theme_ext.dart';
import '../../../data/models/media_content.dart';
import '../shared/media_content_tile.dart';
import '../shared/network_thumbnail.dart';
import '../shared/playing_indicator.dart';
import '../../../providers/audio_player_controller.dart';

/// A big rounded picture, then the title (two lines at most) and a grey line.
/// The one that is loaded is marked: see [_PlayingOverlay].
/// 158 wide with a 158 picture by default: 158 + 8 + 48 + 20 = 234 tall at the
/// normal text size, taller when the system font is larger — see [heightOf].
class FeedCard extends ConsumerWidget {
  const FeedCard({super.key, required this.item, required this.queueItems});

  final MediaContent item;
  final List<MediaContent> queueItems;

  static const width = 158.0;
  static const pictureHeight = 158.0;

  static const _titleSize = 16.0;
  static const _titleLineHeight = 1.5;
  static const _subtitleSize = 14.0;
  static const _subtitleLineHeight = 1.4;

  /// How tall a card must be to hold its two title lines and the grey line at
  /// the system's text size (234 at the normal one). A row of cards is given
  /// this much, so a larger font makes it taller rather than overflowing.
  static double heightOf(BuildContext context) {
    final text = MediaQuery.textScalerOf(context);
    return (pictureHeight +
            8 +
            text.scale(_titleSize) * _titleLineHeight * 2 +
            text.scale(_subtitleSize) * _subtitleLineHeight)
        .ceilToDouble();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final playId = 'media:${item.id}';
    // This card's own state — null unless it is what is loaded — so only a
    // change in that rebuilds it, not every tick of the player.
    final status = ref.watch(
      audioPlayerControllerProvider.select(
        (playback) => playback.item?.id == playId ? playback.status : null,
      ),
    );
    final isCurrent = status != null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => tapToPlay(
        context,
        ref,
        playId: playId,
        onTap: () =>
            playMediaContent(context, ref, item, queueItems: queueItems),
      ),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: width,
              height: pictureHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetworkThumbnail(
                    url: item.thumbnailUrl,
                    width: width,
                    height: pictureHeight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  if (isCurrent) _PlayingOverlay(status: status),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? colors.primary : colors.onSurface,
                fontSize: _titleSize,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                height: _titleLineHeight,
              ),
            ),
            Text(
              item.artistName ?? item.categoryName ?? item.mediaType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.mutedText,
                fontSize: _subtitleSize,
                height: _subtitleLineHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What marks the card of what is loaded: the picture dimmed, with a violet ring
/// round it, and over it the equalizer bars while it plays, a play button while
/// it is paused and a spinner while it loads. It fades in as it is picked.
class _PlayingOverlay extends StatelessWidget {
  const _PlayingOverlay({required this.status});

  final PlaybackStatus status;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: IgnorePointer(
        child: DecoratedBox(
          key: const Key('feedCardPlaying'),
          decoration: BoxDecoration(
            color: const Color(0x66000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary, width: 2),
          ),
          child: Center(
            child: switch (status) {
              PlaybackStatus.playing => const PlayingIndicator(
                width: 44,
                height: 24,
                // Over a picture, where the cover's own colours would vanish.
                coverColors: false,
              ),
              PlaybackStatus.loading => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
              _ => const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            },
          ),
        ),
      ),
    );
  }
}
