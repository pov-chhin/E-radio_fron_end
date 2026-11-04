import 'package:flutter/material.dart';

import '../../../data/models/tag.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../shared/filter_pill.dart';

/// The pill row under the Podcasts title: "All" and one pill per sub-topic
/// (Health, Economy/Finance, …). [selectedId] null means "All".
class PodcastFilterChips extends StatelessWidget {
  const PodcastFilterChips({
    super.key,
    required this.tags,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Tag> tags;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FilterPillRow(
      items: [
        FilterPillItem(id: null, label: l10n.filterAll),
        for (final tag in tags) FilterPillItem(id: tag.id, label: tag.name),
      ],
      selectedId: selectedId,
      onSelected: onSelected,
    );
  }
}
