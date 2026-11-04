import 'package:flutter/material.dart';
import '../../../core/supports/tap_to_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../themes/theme_ext.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../providers/station_provider.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../shared/network_thumbnail.dart';
import '../shared/playing_indicator.dart';
import '../../../providers/recently_played_provider.dart';
import '../../../providers/audio_player_controller.dart';
import 'section_header.dart';

/// What the person last played, stations and media content mixed, most recent
/// first — or null while the stations or the media are still loading.
/// [limit] keeps only the newest few (Home shows six; the See All page all).
List<NowPlayingItem>? jumpBackInItems(WidgetRef ref, {int? limit}) {
  final recentIds = ref.watch(recentlyPlayedProvider);
  if (recentIds.isEmpty) return const [];

  final stations = ref.watch(stationsProvider).asData?.value;

  final mediaIds = recentIds
      .where((id) => id.startsWith('media:'))
      .map((id) => id.substring('media:'.length))
      .join(',');
  final mediaContents = ref
      .watch(mediaContentsByIdsProvider(mediaIds))
      .asData
      ?.value;

  if (stations == null || mediaContents == null) return null;

  final stationsById = {for (final s in stations) 'station:${s.id}': s};
  final mediaById = {for (final m in mediaContents) 'media:${m.id}': m};

  final items = recentIds.map((id) {
    final station = stationsById[id];
    if (station != null) return NowPlayingItem.fromStation(station);
    final media = mediaById[id];
    if (media != null) return NowPlayingItem.fromMediaContent(media);
    return null;
  }).nonNulls;
  return (limit == null ? items : items.take(limit)).toList();
}

/// "Jump Back In": whatever the person last played, stations and media
/// content mixed (most recent first), as a two-column grid of compact cards.
/// Nothing shows until they've played something.
class JumpBackInSection extends ConsumerWidget {
  const JumpBackInSection({super.key});

  static const _previewCount = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = jumpBackInItems(ref, limit: _previewCount);
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.jumpBackIn,
          onSeeAll: () => context.push('/library'),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kExploreGutter),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: JumpBackInCard.height,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => JumpBackInCard(item: items[index]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// A grey pill with the artwork flush to its left edge, the title over a grey
/// second line, and an equaliser mark beside the title while it's playing.
class JumpBackInCard extends ConsumerWidget {
  const JumpBackInCard({super.key, required this.item});

  static const height = 56.0;

  final NowPlayingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final playback = ref.watch(audioPlayerControllerProvider);
    final playedAt = ref.watch(recentlyPlayedAtProvider)[item.id];
    final isPlaying =
        playback.item?.id == item.id &&
        playback.status == PlaybackStatus.playing;

    return Material(
      color: context.softCard,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => tapToPlay(
          context,
          ref,
          playId: item.id,
          onTap: () =>
              ref.read(audioPlayerControllerProvider.notifier).play(item),
        ),
        child: Row(
          children: [
            NetworkThumbnail(
              url: item.artworkUrl,
              width: height,
              height: height,
              borderRadius: BorderRadius.zero,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isPlaying) ...[
                        const PlayingIndicator(width: 14, height: 10),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _playedTimeLabel(context, l10n, playedAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

String _playedTimeLabel(
  BuildContext context,
  AppLocalizations l10n,
  DateTime? playedAt,
) {
  if (playedAt == null) return l10n.recentlyPlayed;

  final local = playedAt.toLocal();
  final age = DateTime.now().difference(local);
  if (age.inMinutes < 60) {
    return l10n.minutesAgo(age.inMinutes.clamp(1, 59));
  }
  if (age.inHours < 24) return l10n.hoursAgo(age.inHours);
  if (age.inDays < 7) return l10n.episodeDaysAgo(age.inDays);
  return MaterialLocalizations.of(context).formatMediumDate(local);
}
