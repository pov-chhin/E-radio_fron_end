import 'package:flutter/material.dart';

import '../../themes/theme_ext.dart';
import '../../../data/models/program.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../screens/podcasts/program_byline.dart';
import 'podcast_artwork_stack.dart';

/// One show in the Podcasts grid: its stacked cover with how many episodes it
/// has ("6 EP"), the name (two lines at most) and a grey "by host • category"
/// line. Tapping opens the show.
class PodcastCard extends StatelessWidget {
  const PodcastCard({super.key, required this.program, required this.onTap});

  final Program program;
  final VoidCallback onTap;

  /// The card's width; a narrower cell shrinks it.
  static const width = 158.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final byline = programByline(l10n, program);
    // "6 EP" on the cover; nothing for a show that doesn't say, or has none.
    final count = program.episodeCount;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PodcastArtworkStack(
              url: program.coverImageUrl,
              badge: count == null || count <= 0
                  ? null
                  : l10n.episodeCountBadge(count),
            ),
            const SizedBox(height: 12),
            Text(
              program.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (byline != null)
              Text(
                byline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.mutedText,
                  fontSize: 14,
                  height: 20 / 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
