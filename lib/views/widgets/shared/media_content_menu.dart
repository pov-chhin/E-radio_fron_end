import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/supports/require_sign_in.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../data/models/media_content.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'dots_menu.dart';
import 'media_content_tile.dart';

/// The ⋮ menu on a media row, as the design's small popup beside the button:
/// play or pause it, add it to the favorites (signed-in only), or share it.
/// [context] must be the ⋮ button's own (use a Builder) — the popup is anchored
/// to it.
Future<void> showMediaContentMenu(
  BuildContext context,
  WidgetRef ref,
  MediaContent item, {
  List<MediaContent>? queueItems,
}) {
  final l10n = AppLocalizations.of(context)!;
  final nowPlaying = NowPlayingItem.fromMediaContent(item);
  final playback = ref.read(audioPlayerControllerProvider);
  final isPlaying =
      nowPlaying != null &&
      playback.item?.id == nowPlaying.id &&
      playback.status == PlaybackStatus.playing;
  final isFavorite = ref.read(favoritesProvider).contains('media:${item.id}');

  return showDotsMenu(context, [
    if (nowPlaying != null)
      DotsMenuItem(
        icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        label: isPlaying ? l10n.pause : l10n.play,
        onTap: () =>
            playMediaContent(context, ref, item, queueItems: queueItems),
      ),
    DotsMenuItem(
      icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      label: isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
      onTap: () => requireSignIn(
        context,
        ref,
        () => ref.read(favoritesProvider.notifier).toggle('media:${item.id}'),
      ),
    ),
    DotsMenuItem(
      icon: Icons.share_rounded,
      label: l10n.share,
      onTap: () => SharePlus.instance.share(ShareParams(text: item.title)),
    ),
  ]);
}
