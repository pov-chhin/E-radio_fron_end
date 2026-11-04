import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/category_pages.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../data/models/category.dart';
import '../../../data/models/media_content.dart';
import 'feed_card.dart';
import 'section_header.dart';

/// One category's latest content as a horizontally scrolling row of large
/// picture cards ("News"). Titled with the category's own name, and "See All"
/// opens the category. Renders nothing while there's no data — a category
/// with nothing in it simply doesn't appear on the home screen.
class CategoryFeedSection extends ConsumerWidget {
  const CategoryFeedSection({
    super.key,
    required this.slug,
    this.items,
    this.categories,
  });

  final String slug;
  final List<MediaContent>? items;
  final List<Category>? categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shownItems =
        items ?? ref.watch(mediaContentsByCategoryProvider(slug)).asData?.value;
    if (shownItems == null || shownItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final shownCategories =
        categories ?? ref.watch(categoriesProvider).asData?.value;
    final name = shownCategories
        ?.where((category) => category.slug == slug)
        .map((category) => category.name)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: name ?? slug,
          onSeeAll: () => openCategory(context, slug),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: FeedCard.heightOf(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kExploreGutter),
            itemCount: shownItems.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                FeedCard(item: shownItems[index], queueItems: shownItems),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
