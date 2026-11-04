import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/program.dart';
import '../../../data/repositories/program_repository.dart';
import '../../../providers/paged_list_notifier.dart';
import '../shared/load_more_footer.dart';
import '../shared/retry_view.dart';
import 'podcast_card.dart';

/// One tab of the Podcasts pages: the shows on [tagId] ("All" when null) as a
/// two-column grid of stacked covers. It lists the first 20 and, once the
/// listener scrolls to the end, fetches the next 20, and so on.
class PagedPodcastGrid extends ConsumerWidget {
  const PagedPodcastGrid({
    super.key,
    required this.tagId,
    required this.emptyMessage,
    required this.onOpen,
  });

  final String? tagId;
  final String emptyMessage;
  final ValueChanged<Program> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = pagedProgramsProvider(tagId);
    final feed = ref.watch(provider);

    return feed.when(
      // A reload (pull-to-refresh, coming back to the app) keeps the old list
      // on screen until the new one is here.
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => RetryView(
        onRetry: () {
          ref.invalidate(programsFirstPage(tagId));
          ref.invalidate(provider);
        },
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(programsFirstPage(tagId));
          await ref.read(provider.future);
        },
        child: data.items.isEmpty
            ? _Empty(message: emptyMessage)
            : _Grid(
                feed: data,
                onOpen: onOpen,
                onLoadMore: ref.read(provider.notifier).loadMore,
              ),
      ),
    );
  }
}

/// Scrollable so pull-to-refresh still works on an empty page.
class _Empty extends StatelessWidget {
  const _Empty({required this.message});

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

/// Two covers a row, each centred in its half so the page keeps the design's
/// 12px gutter between them. Rows are as tall as their taller card. While more
/// pages remain, a footer closes the list.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.feed,
    required this.onOpen,
    required this.onLoadMore,
  });

  final PagedFeed<Program> feed;
  final ValueChanged<Program> onOpen;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final programs = feed.items;
    final rowCount = (programs.length + 1) ~/ 2;

    Widget cell(int index) {
      if (index >= programs.length) return const Expanded(child: SizedBox());
      final program = programs[index];
      return Expanded(
        child: Center(
          child: PodcastCard(program: program, onTap: () => onOpen(program)),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      itemCount: rowCount + (feed.hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, row) {
        if (row == rowCount) {
          return LoadMoreFooter(
            failed: feed.loadMoreFailed,
            onLoad: onLoadMore,
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(row * 2),
            const SizedBox(width: 12),
            cell(row * 2 + 1),
          ],
        );
      },
    );
  }
}
