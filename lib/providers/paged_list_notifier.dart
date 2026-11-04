import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/api_client.dart';

/// How many items the API sends per page; a shorter page is the last one.
const kPageSize = 20;

/// What a paged list has loaded so far, and what is left to load.
class PagedFeed<T> {
  const PagedFeed({
    required this.items,
    this.nextPage = 2,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<T> items;
  final int nextPage;
  final bool hasMore;
  final bool loadingMore;

  /// The last request for [nextPage] failed; the list keeps what it has and
  /// offers a Retry instead of trying again by itself.
  final bool loadMoreFailed;

  PagedFeed<T> copyWith({bool? loadingMore, bool? loadMoreFailed}) => PagedFeed(
    items: items,
    nextPage: nextPage,
    hasMore: hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
  );
}

/// A list the API serves a page (20) at a time, which shows its first page and
/// then grows by one page whenever [loadMore] is called.
///
/// The first page comes from [firstPage], an ordinary provider other screens
/// can share (the Home rows) — and invalidating it resets this list to that
/// page. Later pages are fetched from [pagePath].
abstract class PagedListNotifier<T> extends AsyncNotifier<PagedFeed<T>> {
  /// The provider of the first page of the list.
  FutureProvider<List<T>> get firstPage;

  /// The API path (with its query) that returns page number [page].
  String pagePath(int page);

  T fromJson(Map<String, dynamic> json);

  /// What tells two items apart, so a page that repeats one is not listed twice.
  Object idOf(T item);

  @override
  Future<PagedFeed<T>> build() async {
    final first = await ref.watch(firstPage.future);
    return PagedFeed(items: first, hasMore: first.length >= kPageSize);
  }

  /// Fetches the next page onto the end of the list. Does nothing while one is
  /// already coming, or when the last page has been reached.
  Future<void> loadMore() async {
    final feed = state.value;
    if (feed == null || !feed.hasMore || feed.loadingMore) return;

    final loading = feed.copyWith(loadingMore: true, loadMoreFailed: false);
    state = AsyncData(loading);
    try {
      final page = feed.nextPage;
      final res = await ref.read(apiClientProvider).get(pagePath(page));
      final batch = (res['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
      // The list was reloaded while this page was on its way: it belongs to
      // the old list, not the new one.
      if (!ref.mounted || !identical(state.value, loading)) return;

      // Items move up the list as they are updated, so a page can repeat one
      // the listener has already seen.
      final seen = {for (final item in feed.items) idOf(item)};
      state = AsyncData(
        PagedFeed(
          items: [
            ...feed.items,
            ...batch.where((item) => seen.add(idOf(item))),
          ],
          nextPage: page + 1,
          hasMore: batch.length >= kPageSize,
        ),
      );
    } catch (_) {
      if (!ref.mounted || !identical(state.value, loading)) return;
      state = AsyncData(feed.copyWith(loadMoreFailed: true));
    }
  }
}
