import 'package:flutter/material.dart';

import '../../themes/theme_ext.dart';
import '../../../l10n/gen/app_localizations.dart';

/// The page margin the Explore sections share.
const kExploreGutter = 20.0;

/// A section's title — with an optional [icon] before it — and, when there's
/// somewhere for it to go ([onSeeAll]), a grey "See All" on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.icon,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kExploreGutter),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: colors.onSurface),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 20,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  l10n.seeAll,
                  style: TextStyle(
                    color: context.mutedText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}
