import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/tag.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/podcasts/paged_podcast_grid.dart';
import '../../widgets/podcasts/podcast_filter_chips.dart';

/// The Podcasts page: a big title, a row of topic pills, and the shows as a
/// two-column grid of stacked covers. "All" is every show; a pill narrows the
/// grid to the shows on that topic — the ones filed under it, plus the general
/// ones with an episode tagged with it. Swiping the grid sideways moves to the
/// next or previous pill, and each grid loads its shows 20 at a time.
class PodcastsView extends ConsumerStatefulWidget {
  const PodcastsView({super.key, this.categorySlug = 'podcast'});

  final String categorySlug;

  @override
  ConsumerState<PodcastsView> createState() => _PodcastsViewState();
}

class _PodcastsViewState extends ConsumerState<PodcastsView> {
  final _controller = PageController();

  /// The shown page: 0 is "All", then one per topic pill.
  int _pageIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(List<Tag> topics, String? id) {
    final topicIndex = id == null ? -1 : topics.indexWhere((t) => t.id == id);
    if (id != null && topicIndex < 0) return;
    final index = topicIndex + 1;
    if (index == _pageIndex) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    final topics =
        ref
            .watch(tagsProvider)
            .asData
            ?.value
            .where((tag) => tag.slug == widget.categorySlug)
            .firstOrNull
            ?.children ??
        const <Tag>[];
    if (_pageIndex > topics.length) {
      _pageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
    final tagId = _pageIndex == 0 ? null : topics[_pageIndex - 1].id;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                l10n.podcasts,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 28,
                  height: 36 / 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PodcastFilterChips(
              tags: topics,
              selectedId: tagId,
              onSelected: (id) => _select(topics, id),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: topics.length + 1,
                onPageChanged: (index) => setState(() => _pageIndex = index),
                itemBuilder: (context, index) => PagedPodcastGrid(
                  tagId: index == 0 ? null : topics[index - 1].id,
                  emptyMessage: l10n.noPodcastsYet,
                  onOpen: (program) => context.push('/podcasts/${program.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
