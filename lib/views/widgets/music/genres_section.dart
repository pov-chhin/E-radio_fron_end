import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../shared/filter_pill.dart';
import 'music_section_title.dart';

/// "Genres": a wrapped block of pills led by "All" (violet while no genre is
/// picked). Tapping a genre picks it; tapping it again, or "All", lets go.
class GenresSection extends StatelessWidget {
  const GenresSection({
    super.key,
    required this.genres,
    required this.selected,
    required this.onSelected,
  });

  final List<String> genres;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MusicSectionTitle(l10n.genres),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilterPill(
                label: l10n.filterAll,
                height: 38,
                selected: selected == null,
                onTap: () => onSelected(null),
              ),
              for (final genre in genres)
                FilterPill(
                  label: genre,
                  height: 38,
                  selected: genre == selected,
                  onTap: () => onSelected(genre == selected ? null : genre),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
