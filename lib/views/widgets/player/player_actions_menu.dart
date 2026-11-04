import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/supports/require_sign_in.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../providers/bookmarks_provider.dart';
import '../../../providers/favorites_provider.dart';
import '../../../providers/reminder_provider.dart';
import '../comments/comments_sheet.dart';
import '../shared/dots_menu.dart';

/// The ⋮ on the row that is playing: favorite, comments, bookmark, a reminder
/// and share, in the design's small popup beside the button. [context] must be
/// the ⋮ button's own — the popup is anchored to it.
void showPlayerActionsMenu(
  BuildContext context,
  WidgetRef ref,
  NowPlayingItem item,
) {
  final l10n = AppLocalizations.of(context)!;
  final isFavorite = ref.read(favoritesProvider).contains(item.id);
  final isBookmarked =
      ref.read(bookmarksProvider).value?.contains(item.id) ?? false;
  final reminderAt = ref.read(remindersProvider)[item.id];

  showDotsMenu(context, [
    DotsMenuItem(
      icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      label: isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
      onTap: () => requireSignIn(
        context,
        ref,
        () => ref.read(favoritesProvider.notifier).toggle(item.id),
      ),
    ),
    DotsMenuItem(
      icon: Icons.mode_comment_outlined,
      label: l10n.comments,
      onTap: () => showCommentsSheet(context, ref, (
        type: item.contentType,
        id: item.contentId,
      )),
    ),
    DotsMenuItem(
      icon: isBookmarked
          ? Icons.bookmark_rounded
          : Icons.bookmark_border_rounded,
      label: isBookmarked ? l10n.removeBookmark : l10n.addBookmark,
      onTap: () => requireSignIn(
        context,
        ref,
        () => ref
            .read(bookmarksProvider.notifier)
            .toggle(item.contentType, item.contentId),
      ),
    ),
    DotsMenuItem(
      icon: reminderAt == null
          ? Icons.alarm_add_rounded
          : Icons.alarm_on_rounded,
      label: reminderAt == null
          ? l10n.remindMe
          : l10n.reminderSetFor(DateFormat.MMMd().add_jm().format(reminderAt)),
      onTap: () => reminderAt == null
          ? _createReminder(context, ref, item)
          : _confirmCancel(context, ref, item),
    ),
    DotsMenuItem(
      icon: Icons.share_rounded,
      label: l10n.share,
      onTap: () => SharePlus.instance.share(ShareParams(text: item.title)),
    ),
  ]);
}

/// The ⋮ on any other row of the play list: play it, add it to the favorites,
/// share it. Play steps through [queue] from there — the play list in play, if
/// none is given.
void showQueueItemMenu(
  BuildContext context,
  WidgetRef ref,
  NowPlayingItem item, {
  List<NowPlayingItem>? queue,
}) {
  final l10n = AppLocalizations.of(context)!;
  final isFavorite = ref.read(favoritesProvider).contains(item.id);

  showDotsMenu(context, [
    DotsMenuItem(
      icon: Icons.play_arrow_rounded,
      label: l10n.play,
      onTap: () {
        final playQueue =
            queue ?? ref.read(audioPlayerControllerProvider).queue;
        ref
            .read(audioPlayerControllerProvider.notifier)
            .play(
              item,
              queue: playQueue,
              queueIndex: playQueue.indexWhere((q) => q.id == item.id),
            );
      },
    ),
    DotsMenuItem(
      icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      label: isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
      onTap: () => requireSignIn(
        context,
        ref,
        () => ref.read(favoritesProvider.notifier).toggle(item.id),
      ),
    ),
    DotsMenuItem(
      icon: Icons.share_rounded,
      label: l10n.share,
      onTap: () => SharePlus.instance.share(ShareParams(text: item.title)),
    ),
  ]);
}

Future<void> _createReminder(
  BuildContext context,
  WidgetRef ref,
  NowPlayingItem item,
) async {
  final l10n = AppLocalizations.of(context)!;
  final at = await _pickDateTime(context);
  if (at == null || !context.mounted) return;
  final granted = await ref
      .read(remindersProvider.notifier)
      .set(item.id, item.title, at);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        granted ? l10n.reminderCreated : l10n.notificationsPermissionNeeded,
      ),
    ),
  );
}

Future<void> _confirmCancel(
  BuildContext context,
  WidgetRef ref,
  NowPlayingItem item,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(l10n.cancelReminder),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.cancelReminder),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(remindersProvider.notifier).cancel(item.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.reminderCancelled)));
}

Future<DateTime?> _pickDateTime(BuildContext context) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: now,
    lastDate: now.add(const Duration(days: 365)),
    helpText: AppLocalizations.of(context)!.chooseReminderTime,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
