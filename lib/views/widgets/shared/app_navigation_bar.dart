import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../themes/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';

/// The bottom bar: Discover, Podcasts, Music and Favorites as four 72 × 54
/// buttons with an icon over a small label, on a rounded-top sheet. The picked
/// one is drawn in the brand violet with its filled icon.
class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _iconDirectory = 'assets/icons/nav';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // The bar leaves 28px under the buttons for the home indicator; a phone
    // whose own bottom inset is bigger than that gets the bigger gap.
    final bottomGap = math.max(28.0, MediaQuery.viewPaddingOf(context).bottom);

    final items = [
      (icon: 'house', label: l10n.navExplore, iconSize: 24.0),
      (icon: 'podcasts', label: l10n.podcasts, iconSize: 20.0),
      (icon: 'music', label: l10n.music, iconSize: 24.0),
      (icon: 'heart', label: l10n.navFavorite, iconSize: 24.0),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x296D758F),
            offset: Offset(0, 8),
            blurRadius: 28,
          ),
          BoxShadow(
            color: Color(0x146D758F),
            offset: Offset(0, 2),
            blurRadius: 12,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomGap),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final (index, item) in items.indexed)
                    _NavButton(
                      label: item.label,
                      selected: index == selectedIndex,
                      onTap: () => onSelected(index),
                      icon: SvgPicture.asset(
                        index == selectedIndex
                            ? '$_iconDirectory/${item.icon}_selected.svg'
                            : '$_iconDirectory/${item.icon}.svg',
                        width: item.iconSize,
                        height: item.iconSize,
                        // The artwork is drawn for the light theme; on dark
                        // the unselected ones are re-inked to stay readable.
                        colorFilter:
                            theme.brightness == Brightness.dark &&
                                index != selectedIndex
                            ? ColorFilter.mode(
                                theme.colorScheme.onSurface,
                                BlendMode.srcIn,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(80),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 24, height: 24, child: Center(child: icon)),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? AppColors.brand400 : colors.onSurface,
                  fontSize: 10,
                  // A line box as tall as the letters, so icon + gap + label
                  // add up to the design's 38px.
                  height: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
