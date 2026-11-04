import 'package:flutter/material.dart';
import '../../../core/supports/tap_to_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/station.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../core/supports/require_sign_in.dart';
import 'artwork_avatar.dart';
import 'playing_indicator.dart';

class StationListTile extends ConsumerWidget {
  const StationListTile({super.key, required this.station});

  final Station station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playback = ref.watch(audioPlayerControllerProvider);
    final isCurrent = playback.item?.id == 'station:${station.id}';
    final isPlaying = isCurrent && playback.status == PlaybackStatus.playing;
    final isFavorite = ref
        .watch(favoritesProvider)
        .contains('station:${station.id}');
    final subtitle = station.description?.isNotEmpty == true
        ? station.description!
        : (station.tags.isNotEmpty ? station.tags.join(', ') : null);

    return ListTile(
      leading: ArtworkAvatar(imageUrl: station.coverUrl, size: 48),
      title: Text(station.name),
      subtitle: subtitle != null
          ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent && isPlaying) const PlayingIndicator(),
          IconButton(
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            color: isFavorite ? Theme.of(context).colorScheme.error : null,
            tooltip: isFavorite
                ? l10n.removeFromFavorites
                : l10n.addToFavorites,
            onPressed: () => requireSignIn(
              context,
              ref,
              () => ref
                  .read(favoritesProvider.notifier)
                  .toggle('station:${station.id}'),
            ),
          ),
        ],
      ),
      onTap: () => tapToPlay(
        context,
        ref,
        playId: 'station:${station.id}',
        onTap: () => ref
            .read(audioPlayerControllerProvider.notifier)
            .play(NowPlayingItem.fromStation(station)),
      ),
    );
  }
}
