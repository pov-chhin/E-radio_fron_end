import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/media_content.dart';
import '../../../data/models/tag.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/paged_list_notifier.dart';
import '../../widgets/explore/feed_card.dart';
import '../../widgets/podcasts/paged_podcast_grid.dart';
import '../../widgets/shared/filter_pill.dart';
import '../../widgets/shared/load_more_footer.dart';
import '../../widgets/shared/retry_view.dart';
import '../../widgets/shared/see_all_header.dart';

/// A Discover category using the same header, filter tabs and two-column grid
/// for News, Economy/Finance, Podcast and Health. The content can be swiped
/// horizontally to select the previous or next filter tab.
class CategoryView extends StatelessWidget {
  const CategoryView({super.key, required this.categorySlug});

  final String categorySlug;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: categorySlug == 'podcast'
            ? const _PodcastCategoryPage()
            : _MediaCategoryPage(slug: categorySlug),
      ),
    );
  }
}

class _MediaCategoryPage extends ConsumerStatefulWidget {
  const _MediaCategoryPage({required this.slug});

  final String slug;

  @override
  ConsumerState<_MediaCategoryPage> createState() => _MediaCategoryPageState();
}

class _MediaCategoryPageState extends ConsumerState<_MediaCategoryPage> {
  final _controller = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(List<Tag> tags, String? id) {
    final tagIndex = id == null ? -1 : tags.indexWhere((tag) => tag.id == id);
    if (id != null && tagIndex < 0) return;
    final index = tagIndex + 1;
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
    final slug = widget.slug;
    final title = _categoryTitle(ref, slug);
    final tags = _categoryTags(ref, slug);
    if (_pageIndex > tags.length) {
      _pageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
    final tagId = _pageIndex == 0 ? null : tags[_pageIndex - 1].id;

    return Column(
      children: [
        SeeAllHeader(title: title),
        FilterPillRow(
          items: [
            FilterPillItem(id: null, label: l10n.filterAll),
            for (final tag in tags) FilterPillItem(id: tag.id, label: tag.name),
          ],
          selectedId: tagId,
          onSelected: (id) => _select(tags, id),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: tags.length + 1,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) => _MediaResults(
              slug: slug,
              tagId: index == 0 ? null : tags[index - 1].id,
              emptyMessage: l10n.noContentYet,
            ),
          ),
        ),
      ],
    );
  }
}

class _PodcastCategoryPage extends ConsumerStatefulWidget {
  const _PodcastCategoryPage();

  @override
  ConsumerState<_PodcastCategoryPage> createState() =>
      _PodcastCategoryPageState();
}

class _PodcastCategoryPageState extends ConsumerState<_PodcastCategoryPage> {
  final _controller = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(List<Tag> tags, String? id) {
    final tagIndex = id == null ? -1 : tags.indexWhere((tag) => tag.id == id);
    if (id != null && tagIndex < 0) return;
    final index = tagIndex + 1;
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
    final tags = _categoryTags(ref, 'podcast');
    if (_pageIndex > tags.length) {
      _pageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
    final tagId = _pageIndex == 0 ? null : tags[_pageIndex - 1].id;

    return Column(
      children: [
        SeeAllHeader(title: _categoryTitle(ref, 'podcast')),
        FilterPillRow(
          items: [
            FilterPillItem(id: null, label: l10n.filterAll),
            for (final tag in tags) FilterPillItem(id: tag.id, label: tag.name),
          ],
          selectedId: tagId,
          onSelected: (id) => _select(tags, id),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: tags.length + 1,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            itemBuilder: (context, index) => PagedPodcastGrid(
              tagId: index == 0 ? null : tags[index - 1].id,
              emptyMessage: l10n.noPodcastsYet,
              onOpen: (program) => context.go('/podcasts/${program.id}'),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaResults extends ConsumerWidget {
  const _MediaResults({
    required this.slug,
    required this.tagId,
    required this.emptyMessage,
  });

  final String slug;
  final String? tagId;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (slug: slug, tagId: tagId);
    final provider = pagedMediaContentsProvider(key);
    final content = ref.watch(provider);
    return content.when(
      // A reload (pull-to-refresh, coming back to the app) keeps the old list
      // on screen until the new one is here.
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => RetryView(
        onRetry: () {
          ref.invalidate(mediaContentsFirstPage(key));
          ref.invalidate(provider);
        },
      ),
      data: (feed) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mediaContentsFirstPage(key));
          await ref.read(provider.future);
        },
        child: feed.items.isEmpty
            ? _EmptyList(message: emptyMessage)
            : _MediaGrid(
                feed: feed,
                onLoadMore: ref.read(provider.notifier).loadMore,
              ),
      ),
    );
  }
}

String _categoryTitle(WidgetRef ref, String slug) {
  final serverName = ref
      .watch(categoriesProvider)
      .asData
      ?.value
      .where((category) => category.slug == slug)
      .map((category) => category.name)
      .firstOrNull;
  if (serverName != null) return serverName;
  return switch (slug) {
    'news' => 'News',
    'economyfinance' => 'Economy/Finance',
    'podcast' => 'Podcast',
    'health' => 'Health',
    _ => slug,
  };
}

List<Tag> _categoryTags(WidgetRef ref, String slug) =>
    ref
        .watch(tagsProvider)
        .asData
        ?.value
        .where((tag) => tag.slug == slug)
        .firstOrNull
        ?.children ??
    const <Tag>[];

/// Scrollable even when empty so pull-to-refresh keeps working.
class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: box.maxHeight,
          child: Center(child: Text(message)),
        ),
      ),
    );
  }
}

/// Two cards a row; while more pages remain, a footer closes the list.
class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.feed, required this.onLoadMore});

  final PagedFeed<MediaContent> feed;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final items = feed.items;
    final rowCount = (items.length + 1) ~/ 2;

    Widget cell(int index) => Expanded(
      child: index >= items.length
          ? const SizedBox()
          : Center(
              child: FeedCard(item: items[index], queueItems: items),
            ),
    );

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      itemCount: rowCount + (feed.hasMore ? 1 : 0),
      itemBuilder: (context, row) {
        if (row == rowCount) {
          return LoadMoreFooter(
            failed: feed.loadMoreFailed,
            onLoad: onLoadMore,
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: row == rowCount - 1 ? 0 : 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell(row * 2),
              const SizedBox(width: 12),
              cell(row * 2 + 1),
            ],
          ),
        );
      },
    );
  }
}
