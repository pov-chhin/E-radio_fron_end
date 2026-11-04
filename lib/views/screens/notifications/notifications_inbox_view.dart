import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../themes/app_colors.dart';
import '../../themes/theme_ext.dart';
import '../../../core/supports/notification_permission.dart';
import '../../../core/supports/tap_to_play.dart';
import '../../../data/models/media_content.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/retry_view.dart';
import '../../../providers/notifications_inbox_provider.dart';
import '../../widgets/shared/dots_menu.dart';
import '../../widgets/shared/media_content_tile.dart';
import '../../widgets/shared/network_thumbnail.dart';
import '../../widgets/shared/see_all_header.dart';
import '../../widgets/shared/state_view.dart';

/// The blue of the unread dot and the "mark all as read" tick in the design.
const _unreadBlue = Color(0xFF3B82F6);

/// Where notifications arrive — the page the bell opens. It's the feed of new
/// releases (songs and podcast episodes), newest first, in two groups: the
/// ones that came out since the last visit under "Important" (with a blue
/// dot), everything else under "More notifications". The ⋮ on a row hides it,
/// or asks for fewer / none from its source. With nothing to show it's the
/// "nothing here" page, with a button that asks for permission.
class NotificationsInboxView extends ConsumerStatefulWidget {
  const NotificationsInboxView({super.key});

  @override
  ConsumerState<NotificationsInboxView> createState() =>
      _NotificationsInboxViewState();
}

class _NotificationsInboxViewState
    extends ConsumerState<NotificationsInboxView> {
  /// What counted as "seen" when the page opened — the dots stay for this
  /// visit even though opening the page marks everything seen — until the
  /// person taps "mark all as read".
  late DateTime _seenBefore;

  @override
  void initState() {
    super.initState();
    // Read now, before marking: a lazy read could land after the mark.
    _seenBefore = ref.read(notificationsSeenProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(notificationsSeenProvider.notifier).markAllSeen();
    });
  }

  void _markAllRead() {
    ref.read(notificationsSeenProvider.notifier).markAllSeen();
    setState(() => _seenBefore = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final releases = ref.watch(newReleaseMediaContentsProvider);
    final choices = ref.watch(notificationChoicesProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SeeAllHeader(
              title: l10n.notifications,
              height: 52,
              trailing: InkResponse(
                radius: 20,
                onTap: _markAllRead,
                child: Tooltip(
                  message: l10n.markAllAsRead,
                  child: SvgPicture.asset(
                    'assets/icons/notifications/check_all.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),
            Expanded(
              child: releases.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => RetryView(
                  onRetry: () =>
                      ref.invalidate(newReleaseMediaContentsProvider),
                ),
                data: (all) {
                  final items = choices.visible(all);
                  if (items.isEmpty) return _Empty(l10n: l10n);

                  bool isImportant(MediaContent item) =>
                      (item.publishedAt?.isAfter(_seenBefore) ?? false) &&
                      !choices.fewer.contains(
                        NotificationChoices.sourceOf(item),
                      );
                  final important = [
                    for (final item in items)
                      if (isImportant(item)) item,
                  ];
                  final more = [
                    for (final item in items)
                      if (!isImportant(item)) item,
                  ];

                  return RefreshIndicator(
                    onRefresh: () => ref
                        .read(newReleaseMediaContentsProvider.notifier)
                        .refresh(),
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (important.isNotEmpty) ...[
                          _SectionTitle(l10n.notificationsImportant),
                          for (final item in important)
                            _ReleaseRow(item: item, queue: items, unread: true),
                          const SizedBox(height: 6),
                          Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ],
                        if (more.isNotEmpty) ...[
                          _SectionTitle(l10n.notificationsMore),
                          for (final item in more)
                            _ReleaseRow(
                              item: item,
                              queue: items,
                              unread: false,
                            ),
                        ],
                      ],
                    ),
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

class _Empty extends ConsumerWidget {
  const _Empty({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StateView(
      icon: Icons.notifications_none_rounded,
      iconColor: AppColors.brand400,
      tint: const Color(0xFFECE5FF),
      title: l10n.noNotificationsTitle,
      message: l10n.noNotificationsMessage,
      actions: [
        StateButton.primary(
          label: l10n.enableNotifications,
          width: 220,
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            if (await turnOnNotifications(context, ref)) {
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.notificationsEnabled)),
              );
            }
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One release, as drawn: a blue dot when it's new, the source's round
/// picture, a two-line title over how long ago, the release's own picture and
/// a ⋮ menu. Tap plays it; a double tap opens Now Playing.
class _ReleaseRow extends ConsumerWidget {
  const _ReleaseRow({
    required this.item,
    required this.queue,
    required this.unread,
  });

  final MediaContent item;
  final List<MediaContent> queue;
  final bool unread;

  static String _ago(
    AppLocalizations l10n,
    MaterialLocalizations material,
    DateTime at,
  ) {
    final local = at.toLocal();
    final age = DateTime.now().difference(local);
    if (age.inMinutes < 60) return l10n.minutesAgo(age.inMinutes.clamp(1, 59));
    if (age.inHours < 24) return l10n.hoursAgo(age.inHours);
    final days = age.inDays;
    return days < 7
        ? l10n.episodeDaysAgo(days)
        : material.formatMediumDate(local);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final published = item.publishedAt;
    final source = NotificationChoices.sourceOf(item);

    return InkWell(
      onTap: () => tapToPlay(
        context,
        ref,
        playId: 'media:${item.id}',
        onTap: () => playMediaContent(context, ref, item, queueItems: queue),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        // 74 as drawn, but taller when a bigger text size or a long title
        // needs it — a fixed height would clip the title and date.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 74),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 5,
                height: 40,
                child: unread
                    ? const Center(
                        child: DecoratedBox(
                          key: Key('unread-dot'),
                          decoration: BoxDecoration(
                            color: _unreadBlue,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(width: 5, height: 5),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 11),
              _SourceAvatar(name: source, photoUrl: item.artistPhotoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 16,
                        height: 24 / 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (published != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _ago(
                          l10n,
                          MaterialLocalizations.of(context),
                          published,
                        ),
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
              const SizedBox(width: 12),
              NetworkThumbnail(url: item.thumbnailUrl, width: 64, height: 64),
              const SizedBox(width: 12),
              _RowMenu(item: item, source: source),
            ],
          ),
        ),
      ),
    );
  }
}

/// The source's round picture — the artist's photo, or while that loads (or
/// when they have none) a soft violet circle with their initials.
class _SourceAvatar extends StatelessWidget {
  const _SourceAvatar({required this.name, this.photoUrl});

  final String? name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final words = (name ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    final initials = words.take(2).map((w) => w[0]).join().toUpperCase();

    final fallback = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brand400.withValues(alpha: 0.14),
      ),
      child: initials.isEmpty
          ? const Icon(Icons.music_note_rounded, color: AppColors.brand400)
          : Text(
              initials,
              style: const TextStyle(
                color: AppColors.brand400,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
    );

    final photo = photoUrl;
    if (photo == null) return fallback;
    return ClipOval(
      child: SizedBox(
        width: 44,
        height: 44,
        child: CachedNetworkImage(
          imageUrl: photo,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          placeholder: (context, url) => fallback,
          errorWidget: (context, url, error) => fallback,
        ),
      ),
    );
  }
}

/// The ⋮: hide this one, show fewer from its source, or turn that source off,
/// in the design's small popup beside the button.
class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.item, required this.source});

  final MediaContent item;
  final String? source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final choices = ref.read(notificationChoicesProvider.notifier);
    final source = this.source;

    // The popup is anchored to the button, so it needs the button's own context.
    return Builder(
      builder: (buttonContext) => IconButton(
        tooltip: l10n.moreOptions,
        padding: EdgeInsets.zero,
        // The dots line up with the title's first line, at the row's top; the
        // button is taller than the 24px icon so it is easy to hit.
        alignment: Alignment.topCenter,
        icon: Icon(Icons.more_vert_rounded, size: 24, color: colors.onSurface),
        iconSize: 24,
        style: IconButton.styleFrom(
          minimumSize: const Size(24, 40),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => showDotsMenu(buttonContext, [
          DotsMenuItem(
            asset: 'assets/icons/notifications/eye_off.svg',
            label: l10n.hideNotification,
            onTap: () => choices.hide(item.id),
          ),
          if (source != null) ...[
            DotsMenuItem(
              label: l10n.showFewerFrom(source),
              onTap: () => choices.showFewerFrom(source),
            ),
            DotsMenuItem(
              asset: 'assets/icons/notifications/bell_off.svg',
              label: l10n.turnOffAllFrom(source),
              onTap: () => choices.turnOffAllFrom(source),
            ),
          ],
        ]),
      ),
    );
  }
}
