import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../providers/equalizer_provider.dart';
import '../../themes/theme_ext.dart';
import '../shared/icon_badge.dart';
import 'equalizer_sheet.dart';

/// The settings for playing songs, from the ⋮-side buttons on Now Playing:
/// shuffle, what happens when a song ends (nothing more, the list again, or
/// this song again) and, on Android, the equalizer. Only offered while a song is playing — a station or a
/// podcast episode has no use for them.
Future<void> showSongPlaySettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Over the player, not above it — like the other menus.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) => SongPlaySettingsSheet(
      // Swaps this sheet for the equalizer's.
      onEqualizer: () {
        Navigator.of(sheetContext).pop();
        showEqualizerSheet(context);
      },
    ),
  );
}

class SongPlaySettingsSheet extends ConsumerWidget {
  const SongPlaySettingsSheet({super.key, this.onEqualizer});

  /// Opens the equalizer. The row is left out without it, and on a phone that
  /// has no equalizer to offer.
  final VoidCallback? onEqualizer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playback = ref.watch(audioPlayerControllerProvider);
    final controller = ref.read(audioPlayerControllerProvider.notifier);
    final equalizer = ref.watch(equalizerProvider);
    final hasEqualizer = onEqualizer != null && equalizer.supported;

    Widget repeatTile(RepeatMode mode, IconData icon, String label) {
      final selected = playback.repeat == mode;
      return ListTile(
        leading: IconBadge(icon: icon, active: selected, size: 40),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        selected: selected,
        tileColor: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .10)
            : null,
        trailing: selected ? const Icon(Icons.check_rounded) : null,
        onTap: () => controller.setRepeat(mode),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
              child: Row(
                children: [
                  const IconBadge(icon: Icons.tune_rounded, glow: true),
                  const SizedBox(width: 14),
                  Text(
                    l10n.settings,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 24 / 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _Group(
              children: [
                SwitchListTile(
                  secondary: IconBadge(
                    icon: Icons.shuffle_rounded,
                    active: playback.shuffle,
                    size: 40,
                  ),
                  title: Text(
                    l10n.shuffle,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  value: playback.shuffle,
                  onChanged: (_) => controller.toggleShuffle(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Group(
              children: [
                repeatTile(
                  RepeatMode.off,
                  Icons.repeat_rounded,
                  l10n.repeatOff,
                ),
                const _GroupDivider(),
                repeatTile(
                  RepeatMode.all,
                  Icons.repeat_rounded,
                  l10n.repeatAll,
                ),
                const _GroupDivider(),
                repeatTile(
                  RepeatMode.one,
                  Icons.repeat_one_rounded,
                  l10n.repeatOne,
                ),
              ],
            ),
            if (hasEqualizer) ...[
              const SizedBox(height: 12),
              _Group(
                children: [
                  ListTile(
                    // Lit while the equalizer is on.
                    leading: IconBadge(
                      icon: Icons.equalizer_rounded,
                      active: equalizer.enabled,
                      size: 40,
                    ),
                    title: Text(
                      l10n.equalizer,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: onEqualizer,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A rounded card holding a few rows, with a hairline round it. A [Material]
/// rather than a decorated box so the rows' highlights and ripples show.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.raisedCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.outline),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// The line between two rows of a [_Group], starting at their text.
class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 72, color: context.outline);
  }
}
