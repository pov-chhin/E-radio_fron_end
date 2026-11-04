import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/auth_controller.dart';
import '../../../data/repositories/home_repository.dart';
import '../../../providers/notifications_inbox_provider.dart';
import '../profile/profile_avatar.dart';

/// The top of Discover: the person's picture, a greeting over their first
/// name, and the magnifier and bell on the right. Part of the page itself, so
/// the pages that open from it (See All, Search, Notifications) have their own
/// headers under the same tab bar.
class DiscoverHeader extends ConsumerWidget {
  const DiscoverHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final profile = ref.watch(authControllerProvider);

    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 12),
        child: Row(
          children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push('/profile'),
              child: ProfileAvatar(profile: profile, size: 48),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greetingFor(DateTime.now().hour),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    profile?.firstName ?? l10n.guest,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _HeaderIcon(
              asset: 'assets/icons/search.svg',
              tooltip: l10n.navSearch,
              onPressed: () => context.push('/search'),
            ),
            _HeaderIcon(
              asset: 'assets/icons/notifications.svg',
              tooltip: l10n.notifications,
              onPressed: () => context.push('/notifications'),
              showDot:
                  unreadReleases(
                    ref.watch(notificationsSeenProvider),
                    ref.watch(homeProvider).asData?.value.newReleases ??
                        const [],
                    ref.watch(notificationChoicesProvider),
                  ) >
                  0,
            ),
          ],
        ),
      ),
    );
  }

  static String greetingFor(int hour) {
    if (hour < 12) return 'Good Morning!';
    if (hour < 18) return 'Good Afternoon!';
    return 'Good Evening!';
  }
}

/// A 20px line icon in a 36px button, so the search and bell sit 36px apart as
/// drawn. (Both are dark artwork; on the dark theme they are re-inked.)
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.asset,
    required this.tooltip,
    required this.onPressed,
    this.showDot = false,
  });

  final String asset;
  final String tooltip;
  final VoidCallback onPressed;

  /// A small red dot on the icon's corner — something new to look at.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          SvgPicture.asset(
            asset,
            width: 20,
            height: 20,
            colorFilter: theme.brightness == Brightness.dark
                ? ColorFilter.mode(theme.colorScheme.onSurface, BlendMode.srcIn)
                : null,
          ),
          if (showDot)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5484D),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.scaffoldBackgroundColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
