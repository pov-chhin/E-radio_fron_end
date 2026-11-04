import 'package:flutter/material.dart';
import '../../../core/supports/tap_to_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/supports/require_sign_in.dart';
import '../../themes/theme_ext.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../data/models/station.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'network_thumbnail.dart';
import 'playing_indicator.dart';

/// One station as a 56px row: its picture, the name over a grey line (its
/// description, else its tags), and a ⋮ with the options. Tapping plays it;
/// while it is the loaded station its name turns the brand colour and a small
/// equaliser mark sits beside it.
class StationRow extends ConsumerWidget {
  const StationRow({
    super.key,
    required this.station,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
  });

  final Station station;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final playback = ref.watch(audioPlayerControllerProvider);
    final isCurrent = playback.item?.id == 'station:${station.id}';
    final isPlaying = isCurrent && playback.status == PlaybackStatus.playing;
    final subtitle = station.description?.isNotEmpty == true
        ? station.description!
        : station.tags.join(', ');

    return InkWell(
      onTap: () => tapToPlay(
        context,
        ref,
        playId: 'station:${station.id}',
        onTap: () => ref
            .read(audioPlayerControllerProvider.notifier)
            .play(NowPlayingItem.fromStation(station)),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            NetworkThumbnail(url: station.coverUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
                          station.name,
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
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty)
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
            IconButton(
              tooltip: l10n.moreOptions,
              constraints: const BoxConstraints.tightFor(width: 24, height: 40),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert_rounded,
                color: colors.onSurface,
                size: 24,
              ),
              onPressed: () => _showMenu(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      // Over the player and tab bar, not above them — see the show's menu.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) =>
          _StationMenu(station: station, pageContext: context),
    );
  }
}

class _StationMenu extends ConsumerWidget {
  const _StationMenu({required this.station, required this.pageContext});

  final Station station;

  /// The screen the sheet was opened from — where a sign-in prompt belongs
  /// once the sheet has closed.
  final BuildContext pageContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playback = ref.watch(audioPlayerControllerProvider);
    final isPlaying =
        playback.item?.id == 'station:${station.id}' &&
        playback.status == PlaybackStatus.playing;
    final isFavorite = ref
        .watch(favoritesProvider)
        .contains('station:${station.id}');

    void run(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              station.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            title: Text(isPlaying ? l10n.pause : l10n.play),
            onTap: () => run(() {
              final controller = ref.read(
                audioPlayerControllerProvider.notifier,
              );
              if (playback.item?.id == 'station:${station.id}') {
                controller.togglePlayPause();
              } else {
                controller.play(NowPlayingItem.fromStation(station));
              }
            }),
          ),
          ListTile(
            leading: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            title: Text(
              isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
            ),
            onTap: () => run(
              () => requireSignIn(
                pageContext,
                ref,
                () => ref
                    .read(favoritesProvider.notifier)
                    .toggle('station:${station.id}'),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: Text(l10n.share),
            onTap: () => run(
              () => SharePlus.instance.share(ShareParams(text: station.name)),
            ),
          ),
        ],
      ),
    );
  }
}
