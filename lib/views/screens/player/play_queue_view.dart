import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/now_playing_item.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/audio_player_controller.dart';
import '../../themes/app_colors.dart';
import '../../themes/theme_ext.dart';
import '../../widgets/player/player_actions_menu.dart';
import '../../widgets/shared/network_thumbnail.dart';
import '../../widgets/shared/see_all_header.dart';

/// The page behind Now Playing's ⋮: the list of what is playing — the songs
/// the current one was started from — one row each, like any other list: the
/// picture, a title over a grey line, a ⋮. The row that is playing is outlined
/// in the brand violet; tapping another plays it, and the outline follows.
class PlayQueueView extends ConsumerStatefulWidget {
  const PlayQueueView({super.key});

  @override
  ConsumerState<PlayQueueView> createState() => _PlayQueueViewState();
}

class _PlayQueueViewState extends ConsumerState<PlayQueueView> {
  /// A row is the 56px picture with 4px above and below, inside a 2px outline,
  /// and 4px of air between one row and the next.
  static const _rowExtent = 72.0;

  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    // Opens with the playing row in view, one above it for context.
    final playback = ref.read(audioPlayerControllerProvider);
    final index = _queueOf(
      playback,
    ).indexWhere((item) => item.id == playback.item?.id);
    _scroll = ScrollController(
      initialScrollOffset: math.max(0, index - 1) * _rowExtent,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Anything played with no list around it is a list of one.
  static List<NowPlayingItem> _queueOf(PlaybackState playback) {
    final current = playback.item;
    return playback.queue.isEmpty && current != null
        ? [current]
        : playback.queue;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playback = ref.watch(audioPlayerControllerProvider);
    final queue = _queueOf(playback);
    final currentId = playback.item?.id;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SeeAllHeader(title: l10n.playlist),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                itemExtent: _rowExtent,
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final item = queue[index];
                  final isCurrent = item.id == currentId;
                  return _QueueRow(
                    item: item,
                    isCurrent: isCurrent,
                    isLoading:
                        isCurrent && playback.status == PlaybackStatus.loading,
                    onTap: isCurrent
                        ? () => context.pop()
                        : () => ref
                              .read(audioPlayerControllerProvider.notifier)
                              .play(item, queue: queue, queueIndex: index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends ConsumerWidget {
  const _QueueRow({
    required this.item,
    required this.isCurrent,
    required this.isLoading,
    required this.onTap,
  });

  final NowPlayingItem item;
  final bool isCurrent;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final subtitle = item.subtitle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent ? AppColors.brand400 : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
          child: Row(
            children: [
              Expanded(
                // Not the whole row, so the ⋮ keeps its own tap.
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap,
                  child: Row(
                    children: [
                      NetworkThumbnail(url: item.artworkUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                            if (subtitle != null && subtitle.isNotEmpty)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.mutedText,
                                  fontSize: 14,
                                  height: 20 / 14,
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
                const SizedBox(
                  width: 36,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                )
              else
                // The popup hangs from the button, so it gets the button's own
                // context.
                Builder(
                  builder: (buttonContext) => IconButton(
                    tooltip: l10n.moreOptions,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: colors.onSurface,
                      size: 24,
                    ),
                    onPressed: () => isCurrent
                        ? showPlayerActionsMenu(buttonContext, ref, item)
                        : showQueueItemMenu(buttonContext, ref, item),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
