import 'package:flutter/material.dart';
import '../../../core/supports/tap_to_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/theme_ext.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../data/models/media_content.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'media_content_menu.dart';
import 'network_thumbnail.dart';

/// Plays [item] — or pauses/resumes it if it's what's already loaded, or says
/// there's nothing to play when it has no stream. [queueItems] is the list the
/// item is shown in, so Now Playing's next/previous have something to step
/// through; it defaults to just [item].
void playMediaContent(
  BuildContext context,
  WidgetRef ref,
  MediaContent item, {
  List<MediaContent>? queueItems,
}) {
  final nowPlaying = NowPlayingItem.fromMediaContent(item);
  if (nowPlaying == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.streamUnavailable)),
    );
    return;
  }

  final controller = ref.read(audioPlayerControllerProvider.notifier);
  if (ref.read(audioPlayerControllerProvider).item?.id == nowPlaying.id) {
    controller.togglePlayPause();
    return;
  }

  final queue = (queueItems ?? [item])
      .map(NowPlayingItem.fromMediaContent)
      .nonNulls
      .toList();
  final queueIndex = queue.indexWhere((q) => q.id == nowPlaying.id);
  controller.play(
    nowPlaying,
    queue: queue.isEmpty ? [nowPlaying] : queue,
    queueIndex: queueIndex < 0 ? 0 : queueIndex,
  );
}

/// One row: a rounded thumbnail, the title and a grey second line, and a ⋮
/// that opens the options menu. Tapping the row plays it; while it's the loaded
/// item its title turns the brand colour, and the ⋮ becomes a spinner while it
/// loads.
class MediaContentTile extends ConsumerWidget {
  const MediaContentTile({
    super.key,
    required this.item,
    this.queueItems,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    this.byArtist = false,
    this.gap = 12,
  });

  final MediaContent item;

  /// The list [item] is shown in; see [playMediaContent].
  final List<MediaContent>? queueItems;

  final EdgeInsetsGeometry padding;

  /// Write the artist as "by Suly Pheng" instead of just the name.
  final bool byArtist;

  /// The space between the picture and the text.
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final nowPlaying = NowPlayingItem.fromMediaContent(item);
    final playback = ref.watch(audioPlayerControllerProvider);
    final isCurrent = nowPlaying != null && playback.item?.id == nowPlaying.id;
    final isLoading = isCurrent && playback.status == PlaybackStatus.loading;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            // Not the whole row, so the ⋮ button keeps its own tap.
            child: InkWell(
              onTap: () => tapToPlay(
                context,
                ref,
                playId: 'media:${item.id}',
                onTap: () => playMediaContent(
                  context,
                  ref,
                  item,
                  queueItems: queueItems,
                ),
              ),
              child: Row(
                children: [
                  NetworkThumbnail(url: item.thumbnailUrl),
                  SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent
                                ? colors.primary
                                : colors.onSurface,
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        Text(
                          byArtist && item.artistName != null
                              ? l10n.byArtist(item.artistName!)
                              : item.artistName ??
                                    item.categoryName ??
                                    item.mediaType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(9),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            // The popup is anchored to the button, so it gets the button's own
            // context.
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
                  item,
                  queueItems: queueItems,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
