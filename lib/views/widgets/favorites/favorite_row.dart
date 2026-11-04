import 'package:flutter/material.dart';
import '../../../core/supports/tap_to_play.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/theme_ext.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../shared/network_thumbnail.dart';
import '../../../providers/audio_player_controller.dart';

/// One favorite: a rounded picture, the name and a grey second line, and a ⋮
/// that opens a small card with a single "Remove from favorites" action.
/// Tapping the row plays it; while it's what's loaded in the player its name
/// turns the brand colour.
class FavoriteRow extends ConsumerWidget {
  const FavoriteRow({
    super.key,
    required this.playId,
    required this.title,
    required this.onTap,
    required this.onRemove,
    this.subtitle,
    this.thumbnailUrl,
  });

  /// The player's id for this item ('station:3', 'media:12').
  final String playId;
  final String title;
  final String? subtitle;
  final String? thumbnailUrl;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final isCurrent =
        ref.watch(audioPlayerControllerProvider.select((s) => s.item?.id)) ==
        playId;
    final subtitle = this.subtitle;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => tapToPlay(context, ref, playId: playId, onTap: onTap),
      child: Row(
        children: [
          NetworkThumbnail(url: thumbnailUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent ? colors.primary : colors.onSurface,
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
              ],
            ),
          ),
          // The button's own padding is the 12px gap and the 12px margin, so
          // the icon sits where the design puts it. A Builder lets the menu
          // find where the button is.
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: l10n.moreOptions,
              icon: Icon(
                Icons.more_vert_rounded,
                color: colors.onSurface,
                size: 24,
              ),
              onPressed: () => _openMenu(buttonContext),
            ),
          ),
        ],
      ),
    );
  }

  /// A white card just under the ⋮ icon, over a barely-there scrim.
  Future<void> _openMenu(BuildContext buttonContext) {
    final l10n = AppLocalizations.of(buttonContext)!;
    // The row is gone once it's removed, so keep hold of the messenger now.
    final messenger = ScaffoldMessenger.of(buttonContext);
    final button = buttonContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(buttonContext, rootOverlay: true).context.findRenderObject()!
            as RenderBox;
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    // 5px under the icon, which is centred in the button.
    final top = origin.dy + button.size.height / 2 + 12 + 5;
    // Its right edge sits 9px inside the icon's, as drawn (the icon is inset
    // 12px in the button).
    final right = overlay.size.width - (origin.dx + button.size.width) + 12 + 9;
    final colors = Theme.of(buttonContext).colorScheme;
    final cardColor = buttonContext.raisedCard;

    return showGeneralDialog<void>(
      context: buttonContext,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(
        buttonContext,
      ).modalBarrierDismissLabel,
      barrierColor: const Color(0x0A000000),
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Stack(
        children: [
          Positioned(
            top: top,
            right: right,
            child: FadeTransition(
              opacity: animation,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      offset: Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      onRemove();
                      messenger.showSnackBar(
                        SnackBar(content: Text(l10n.removedFromFavorites)),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: colors.onSurface,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.removeFromFavorites,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 14,
                              height: 20 / 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
