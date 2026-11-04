import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../../themes/theme_ext.dart';

/// A rounded square holding an icon: the brand gradient with a white icon when
/// [active], a soft grey one with a muted icon when not. The icon fades between
/// the two, so a switch or a choice can light it up as it is turned on.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.active = true,
    this.size = 44,
    this.glow = false,
  });

  final IconData icon;
  final bool active;
  final double size;

  /// A soft violet shadow under the badge while it is [active].
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: active ? AppColors.brandBadgeGradient : null,
        color: active ? null : context.softCard,
        borderRadius: BorderRadius.circular(size * .32),
        boxShadow: active && glow
            ? [
                BoxShadow(
                  color: AppColors.brand400.withValues(alpha: .35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: size * .5,
        color: active ? Colors.white : context.mutedText,
      ),
    );
  }
}
