import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/category_pages.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/program_repository.dart';
import '../../../data/models/category.dart';
import '../../../data/models/program.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../podcasts/podcast_card.dart';
import 'section_header.dart';

/// The home row of podcasts: each show as a stacked cover with its name and
/// host, newest episode first. A card opens the show, "See All" the Podcasts
/// page. Renders nothing while there are no shows to list — a show appears
/// once it is published and has an episode that is public and ready.
class PodcastFeedSection extends ConsumerWidget {
  const PodcastFeedSection({super.key, this.programs, this.categories});

  final List<Program>? programs;
  final List<Category>? categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shownPrograms = programs ?? ref.watch(programsProvider).asData?.value;
    if (shownPrograms == null || shownPrograms.isEmpty) {
      return const SizedBox.shrink();
    }

    final shownCategories =
        categories ?? ref.watch(categoriesProvider).asData?.value;
    final name = shownCategories
        ?.where((category) => category.slug == 'podcast')
        .map((category) => category.name)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: name ?? AppLocalizations.of(context)!.podcasts,
          onSeeAll: () => openCategory(context, 'podcast'),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kExploreGutter),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, program) in shownPrograms.indexed) ...[
                if (index > 0) const SizedBox(width: 12),
                PodcastCard(
                  program: program,
                  onTap: () => context.go('/podcasts/${program.id}'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
