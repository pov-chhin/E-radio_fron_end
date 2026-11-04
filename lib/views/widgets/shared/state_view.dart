import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../themes/app_colors.dart';
import '../../themes/theme_ext.dart';

/// A page with nothing to show — no favorites, no notifications, no
/// connection, content gone: a round tinted badge with an icon, a title, a
/// grey explanation and, optionally, buttons. Centred in the space it's given.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.tint,
    required this.title,
    required this.message,
    this.actions = const [],
    this.horizontalPadding = 32,
    this.sectionGap = 24,
    this.textGap = 10,
  });

  final IconData icon;

  /// The icon's colour, and [tint] the badge behind it (a pale wash of it).
  final Color iconColor;
  final Color tint;
  final String title;
  final String message;
  final List<Widget> actions;
  final double horizontalPadding;

  /// The space between the badge, the text and the buttons.
  final double sectionGap;
  final double textGap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? iconColor.withValues(alpha: .16) : tint,
              ),
              child: Icon(icon, size: 54, color: iconColor),
            ),
            SizedBox(height: sectionGap),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 24,
                height: 32 / 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: textGap),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 16,
                height: 24 / 16,
              ),
            ),
            for (var i = 0; i < actions.length; i++) ...[
              SizedBox(height: i == 0 ? sectionGap : 12),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A 48px pill button for a [StateView]: solid violet, or an outline.
class StateButton extends StatelessWidget {
  const StateButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.width,
  }) : outlined = false;

  const StateButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.width,
  }) : outlined = true;

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  /// Null stretches to whatever the column allows.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      child: Material(
        color: outlined ? Colors.transparent : AppColors.brand400,
        shape: StadiumBorder(
          side: outlined
              ? const BorderSide(color: AppColors.brand400, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: outlined ? AppColors.brand400 : Colors.white,
                fontSize: 16,
                height: 20 / 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header a [StateView] page carries: a back arrow, the title centred, and
/// room on the right to keep it centred.
class StateHeader extends ConsumerWidget {
  const StateHeader({super.key, required this.title, this.onBack});

  final String title;

  /// Defaults to popping the page, or going to Discover if there is none.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          InkResponse(
            radius: 24,
            onTap:
                onBack ??
                () => context.canPop() ? context.pop() : context.go('/explore'),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 24,
                color: colors.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 20,
                height: 28 / 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Balances the back arrow so the title stays centred.
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}
