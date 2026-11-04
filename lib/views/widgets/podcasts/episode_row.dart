import 'package:flutter/material.dart';
import '../../../core/supports/tap_to_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/theme_ext.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../data/models/media_content.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../shared/media_content_menu.dart';
import '../shared/media_content_tile.dart';
import '../shared/network_thumbnail.dart';
import '../../../providers/audio_player_controller.dart';

/// "38 mins • Today": how long an episode runs and when it came out, each only
/// when known. A week or more back it's the date instead of "N days ago".
String? episodeMetaLine(
  BuildContext context,
  MediaContent episode, {
  DateTime? now,
}) => episodeMeta(
  context,
  durationSeconds: episode.durationSeconds,
  publishedAt: episode.publishedAt,
  now: now,
);

/// [episodeMetaLine] for anything with a run time and a publish date — Now
/// Playing's "About the episode" has them without having a [MediaContent].
String? episodeMeta(
  BuildContext context, {
  int? durationSeconds,
  DateTime? publishedAt,
  DateTime? now,
}) {
  final l10n = AppLocalizations.of(context)!;
  final parts = <String>[];

  final seconds = durationSeconds;
  if (seconds != null && seconds > 0) {
    parts.add(l10n.episodeMinutes((seconds / 60).round().clamp(1, 1 << 30)));
  }

  final published = publishedAt?.toLocal();
  if (published != null) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final days = (today.difference(DateUtils.dateOnly(published)).inHours / 24)
        .round();
    parts.add(
      days <= 0
          ? l10n.episodeToday
          : days < 7
          ? l10n.episodeDaysAgo(days)
          : MaterialLocalizations.of(context).formatMediumDate(published),
    );
  }

  return parts.isEmpty ? null : parts.join(' • ');
}

/// One numbered episode in a show: a white rounded row with its number, a
/// small picture, the title and the run time / age, and a ⋮ that opens the
/// options menu. Tapping the row plays it; while it's the loaded episode its
/// title turns the brand colour and the ⋮ becomes a spinner as it loads.
class EpisodeRow extends ConsumerWidget {
  const EpisodeRow({
    super.key,
    required this.number,
    required this.episode,
    required this.queueItems,
  });

  final int number;
  final MediaContent episode;

  /// The show's episodes, so Now Playing's next/previous have somewhere to go.
  final List<MediaContent> queueItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final nowPlaying = NowPlayingItem.fromMediaContent(episode);
    final playback = ref.watch(audioPlayerControllerProvider);
    final isCurrent = nowPlaying != null && playback.item?.id == nowPlaying.id;
    final isLoading = isCurrent && playback.status == PlaybackStatus.loading;
    final meta = episodeMetaLine(context, episode);

    return Material(
      color: context.raisedCard,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => tapToPlay(
          context,
          ref,
          playId: 'media:${episode.id}',
          onTap: () =>
              playMediaContent(context, ref, episode, queueItems: queueItems),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              NetworkThumbnail(
                url: episode.thumbnailUrl,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? colors.primary : colors.onSurface,
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: isCurrent
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 14,
                          height: 20 / 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isLoading)
                const SizedBox(
                  width: 24,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else
                // The popup is anchored to the button, so it gets the button's
                // own context.
                Builder(
                  builder: (buttonContext) => IconButton(
                    tooltip: l10n.moreOptions,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: colors.onSurface,
                      size: 24,
                    ),
                    onPressed: () => showMediaContentMenu(
                      buttonContext,
                      ref,
                      episode,
                      queueItems: queueItems,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
