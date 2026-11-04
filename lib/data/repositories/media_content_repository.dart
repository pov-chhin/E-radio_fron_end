import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cached_list_notifier.dart';
import '../../providers/paged_list_notifier.dart';
import '../services/api_client.dart';
import '../models/media_content.dart';

final mediaContentsByCategoryProvider =
    FutureProvider.family<List<MediaContent>, String>((
      ref,
      categorySlug,
    ) async {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/media-contents?category=$categorySlug');
      final list = (res['data'] as List).cast<Map<String, dynamic>>();
      return list.map(MediaContent.fromJson).toList();
    });

/// Includes content tagged with any descendant of [tagId] (handled server-side).
final mediaContentsByTagProvider =
    FutureProvider.family<List<MediaContent>, String>((ref, tagId) async {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/media-contents?tag_id=$tagId');
      final list = (res['data'] as List).cast<Map<String, dynamic>>();
      return list.map(MediaContent.fromJson).toList();
    });

/// One tab of a category page: the category's [slug], and the sub-topic
/// [tagId] picked on it (null is "All").
typedef MediaListKey = ({String slug, String? tagId});

/// The first page of the content on a category page's tab.
FutureProvider<List<MediaContent>> mediaContentsFirstPage(MediaListKey key) =>
    key.tagId == null
    ? mediaContentsByCategoryProvider(key.slug)
    : mediaContentsByTagProvider(key.tagId!);

/// The content on a category page's tab a page at a time.
class PagedMediaContentsNotifier extends PagedListNotifier<MediaContent> {
  PagedMediaContentsNotifier(this.key);

  final MediaListKey key;

  @override
  FutureProvider<List<MediaContent>> get firstPage =>
      mediaContentsFirstPage(key);

  @override
  String pagePath(int page) => key.tagId == null
      ? '/media-contents?category=${key.slug}&page=$page'
      : '/media-contents?tag_id=${key.tagId}&page=$page';

  @override
  MediaContent fromJson(Map<String, dynamic> json) =>
      MediaContent.fromJson(json);

  @override
  Object idOf(MediaContent item) => item.id;
}

final pagedMediaContentsProvider =
    AsyncNotifierProvider.family<
      PagedMediaContentsNotifier,
      PagedFeed<MediaContent>,
      MediaListKey
    >(PagedMediaContentsNotifier.new);

/// Batch lookup by id (comma-joined), e.g. resolving recently-played media
/// content ids against the catalog. Empty [ids] short-circuits to avoid a
/// pointless request.
final mediaContentsByIdsProvider =
    FutureProvider.family<List<MediaContent>, String>((ref, ids) async {
      if (ids.isEmpty) return [];
      final client = ref.read(apiClientProvider);
      final res = await client.get('/media-contents?ids=$ids');
      final list = (res['data'] as List).cast<Map<String, dynamic>>();
      return list.map(MediaContent.fromJson).toList();
    });

/// A list of media content that opens instantly from the copy of its top kept
/// on the device (see [CachedListNotifier]) — for the lists on the top of the
/// Home screen. [path] is the API path that returns it.
class MediaContentListNotifier extends CachedListNotifier<MediaContent> {
  MediaContentListNotifier({required this.path});

  @override
  final String path;

  @override
  MediaContent fromJson(Map<String, dynamic> json) =>
      MediaContent.fromJson(json);

  @override
  String? imageUrl(MediaContent item) => item.thumbnailUrl;
}

typedef MediaContentListProvider =
    AsyncNotifierProvider<MediaContentListNotifier, List<MediaContent>>;

/// First page (20) of latest content, newest first — sliced client-side for
/// the Home preview row, shown in full on the "See All" screen.
final newReleaseMediaContentsProvider = MediaContentListProvider(
  () => MediaContentListNotifier(path: '/media-contents'),
);

/// First page (20), ordered by play count.
final trendingMediaContentsProvider = FutureProvider<List<MediaContent>>((
  ref,
) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get('/media-contents?sort=trending');
  final list = (res['data'] as List).cast<Map<String, dynamic>>();
  return list.map(MediaContent.fromJson).toList();
});

/// First page (20) of programs across all categories, ordered by play count.
/// This cached provider is used by the Explore preview and its "See All" page.
final trendingProgramMediaContentsProvider = MediaContentListProvider(
  () => MediaContentListNotifier(path: '/media-contents?sort=trending'),
);

/// The songs filter the Music page sends: [tagIds] (comma-joined, empty for
/// none) keeps songs under any of those tags or a tag nested in them, and
/// [artistId] keeps one artist's.
typedef SongFilter = ({String tagIds, String? artistId});

/// First page (20) of songs, most-played first, narrowed by [SongFilter].
final popularSongsProvider =
    FutureProvider.family<List<MediaContent>, SongFilter>((ref, filter) async {
      final client = ref.read(apiClientProvider);
      final params = [
        'category=song',
        'sort=trending',
        if (filter.tagIds.isNotEmpty) 'tag_ids=${filter.tagIds}',
        if (filter.artistId != null) 'artist_id=${filter.artistId}',
      ];
      final res = await client.get('/media-contents?${params.join('&')}');
      final list = (res['data'] as List).cast<Map<String, dynamic>>();
      return list.map(MediaContent.fromJson).toList();
    });
