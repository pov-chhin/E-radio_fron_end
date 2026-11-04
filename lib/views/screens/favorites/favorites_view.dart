import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../themes/app_colors.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../data/models/category.dart';
import '../../../data/models/media_content.dart';
import '../../../data/models/station.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../providers/station_provider.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/retry_view.dart';
import '../../widgets/shared/filter_pill.dart';
import '../../widgets/shared/media_content_tile.dart';
import '../../widgets/shared/state_view.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../providers/auth_controller.dart';
import '../../../providers/favorites_provider.dart';
import '../../widgets/favorites/favorite_row.dart';

/// Favorites: a big title, a row of pills — "All", "Radio" (stations) and then
/// one per category — and the favorites in the chosen group, each with a ⋮ to
/// remove it. Swiping the list sideways moves to the next or previous pill.
/// Guests are asked to sign in instead.
class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  ConsumerState<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends ConsumerState<FavoritesView> {
  static const _radio = 'radio';

  /// Pages are All, Radio, then one per category — the order of the pills.
  /// Not kept in page storage: the pages go away when nothing is saved, and
  /// come back on All.
  final _controller = PageController(keepPage: false);
  int _pageIndex = 0;

  /// The media ids the catalog lookup was made for. It only changes when a
  /// favorite is added that the lookup didn't cover — removing one just hides a
  /// row, so the list doesn't flash a spinner.
  String _mediaKey = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(List<Category> categories, String? id) {
    final int index;
    if (id == null) {
      index = 0;
    } else if (id == _radio) {
      index = 1;
    } else {
      final category = categories.indexWhere((c) => c.slug == id);
      if (category < 0) return;
      index = category + 2;
    }
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
    final profile = ref.watch(authControllerProvider);

    // The pages are rebuilt from the first when they come back.
    if (profile == null || ref.watch(favoritesProvider).isEmpty) {
      _pageIndex = 0;
    }

    final title = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        l10n.favorites,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 28,
          height: 36 / 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (profile == null) {
      return SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.guestSubtitle, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.push('/profile/login'),
                        child: Text(l10n.signIn),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final favoriteIds = ref.watch(favoritesProvider);

    // Nothing saved anywhere yet: a page of its own instead of pills over
    // an empty list.
    if (favoriteIds.isEmpty) {
      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            StateHeader(
              title: l10n.favorites,
              onBack: () => context.go('/explore'),
            ),
            Expanded(
              child: StateView(
                icon: Icons.favorite_border_rounded,
                iconColor: AppColors.brand400,
                tint: const Color(0xFFECE5FF),
                title: l10n.noFavorites,
                message: l10n.emptyFavoritesMessage,
                actions: [
                  StateButton.primary(
                    label: l10n.exploreContent,
                    width: 200,
                    onPressed: () => context.go('/explore'),
                  ),
                ],
              ),
            ),
            // Room for where the tab bar would be.
            const SizedBox(height: 24),
          ],
        ),
      );
    }
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <Category>[];

    final mediaIds = [
      for (final id in favoriteIds)
        if (id.startsWith('media:')) id.substring('media:'.length),
    ];
    final covered = _mediaKey.isEmpty ? const <String>{} : _mediaKey.split(',');
    if (!mediaIds.every(covered.contains)) {
      _mediaKey = (mediaIds..sort()).join(',');
    }

    final pageCount = categories.length + 2;
    if (_pageIndex >= pageCount) {
      _pageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
    final selectedId = switch (_pageIndex) {
      0 => null,
      1 => _radio,
      _ => categories[_pageIndex - 2].slug,
    };

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          FilterPillRow(
            items: [
              FilterPillItem(id: null, label: l10n.filterAll),
              FilterPillItem(id: _radio, label: l10n.tabRadio),
              for (final category in categories)
                FilterPillItem(id: category.slug, label: category.name),
            ],
            selectedId: selectedId,
            onSelected: (id) => _select(categories, id),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: pageCount,
              onPageChanged: (index) => setState(() => _pageIndex = index),
              // Keyed by the page count: a PageView that gains pages (the
              // categories arrived) but whose visible page is unchanged skips
              // its layout and keeps the old scroll limit, so a swipe or a
              // pill tap would stop at the old last page.
              itemBuilder: (context, index) => KeyedSubtree(
                key: ValueKey(pageCount),
                child: switch (index) {
                  0 => _AllFavorites(
                    favoriteIds: favoriteIds,
                    mediaKey: _mediaKey,
                  ),
                  1 => _StationFavorites(favoriteIds: favoriteIds),
                  _ => _MediaFavorites(
                    categorySlug: categories[index - 2].slug,
                    favoriteIds: favoriteIds,
                    mediaKey: _mediaKey,
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rows run to 14 from the edge because the ⋮ button carries 12 of its own
/// margin: that puts the icon where the design has it and gives a title 240.
const _listPadding = EdgeInsets.fromLTRB(20, 16, 14, 16);

Widget _separator(BuildContext context, int index) => const SizedBox(height: 8);

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(AppLocalizations.of(context)!.noFavorites));
}

/// A list that shows its first 20 rows and adds 20 more each time a swipe up
/// brings it near the end, until every row is there.
class _PagedList extends StatefulWidget {
  const _PagedList({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<_PagedList> {
  static const _pageSize = 20;

  /// How close to the end, in pixels, the next page is added.
  static const _nearEnd = 300.0;

  final _controller = ScrollController();
  int _shown = _pageSize;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_showMore);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMore() {
    if (_shown >= widget.itemCount || !_controller.hasClients) return;
    final position = _controller.position;
    if (position.haveDimensions && position.extentAfter < _nearEnd) {
      setState(() => _shown += _pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A first page too short to scroll never fires the controller, so look
    // again once it's laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showMore();
    });

    return ListView.separated(
      controller: _controller,
      padding: _listPadding,
      itemCount: math.min(_shown, widget.itemCount),
      separatorBuilder: _separator,
      itemBuilder: widget.itemBuilder,
    );
  }
}

FavoriteRow _stationRow(WidgetRef ref, Station station) => FavoriteRow(
  playId: 'station:${station.id}',
  title: station.name,
  subtitle: station.description?.isNotEmpty == true
      ? station.description
      : (station.tags.isNotEmpty ? station.tags.join(', ') : null),
  thumbnailUrl: station.coverUrl,
  onTap: () => ref
      .read(audioPlayerControllerProvider.notifier)
      .play(NowPlayingItem.fromStation(station)),
  onRemove: () =>
      ref.read(favoritesProvider.notifier).toggle('station:${station.id}'),
);

/// [queue] is the group the item was listed in; playing it queues the rest.
FavoriteRow _mediaRow(
  BuildContext context,
  WidgetRef ref,
  MediaContent item,
  List<MediaContent> queue,
) => FavoriteRow(
  playId: 'media:${item.id}',
  title: item.title,
  subtitle: item.artistName ?? item.categoryName,
  thumbnailUrl: item.thumbnailUrl,
  onTap: () => playMediaContent(context, ref, item, queueItems: queue),
  onRemove: () =>
      ref.read(favoritesProvider.notifier).toggle('media:${item.id}'),
);

/// Everything saved: the stations, then the songs, podcasts and so on.
class _AllFavorites extends ConsumerWidget {
  const _AllFavorites({required this.favoriteIds, required this.mediaKey});

  final Set<String> favoriteIds;
  final String mediaKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(stationsProvider);
    // Nothing to look up when only stations are saved.
    final mediaAsync = mediaKey.isEmpty
        ? null
        : ref.watch(mediaContentsByIdsProvider(mediaKey));

    if (stationsAsync.hasError || (mediaAsync?.hasError ?? false)) {
      return RetryView(
        onRetry: () {
          ref.read(stationsProvider.notifier).refresh();
          if (mediaAsync != null) {
            ref.invalidate(mediaContentsByIdsProvider(mediaKey));
          }
        },
      );
    }

    final allStations = stationsAsync.value;
    final allMedia = mediaAsync == null
        ? const <MediaContent>[]
        : mediaAsync.value;
    if (allStations == null || allMedia == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stations = [
      for (final station in allStations)
        if (favoriteIds.contains('station:${station.id}')) station,
    ];
    final items = [
      for (final item in allMedia)
        if (favoriteIds.contains('media:${item.id}')) item,
    ];
    if (stations.isEmpty && items.isEmpty) return const _Empty();

    return _PagedList(
      itemCount: stations.length + items.length,
      itemBuilder: (context, index) => index < stations.length
          ? _stationRow(ref, stations[index])
          : _mediaRow(context, ref, items[index - stations.length], items),
    );
  }
}

/// The favorite stations.
class _StationFavorites extends ConsumerWidget {
  const _StationFavorites({required this.favoriteIds});

  final Set<String> favoriteIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationsProvider);

    return stations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => RetryView(
        onRetry: () => ref.read(stationsProvider.notifier).refresh(),
      ),
      data: (all) {
        final favorites = [
          for (final station in all)
            if (favoriteIds.contains('station:${station.id}')) station,
        ];
        if (favorites.isEmpty) return const _Empty();

        return _PagedList(
          itemCount: favorites.length,
          itemBuilder: (context, index) => _stationRow(ref, favorites[index]),
        );
      },
    );
  }
}

/// The favorite songs, podcasts and so on in one category.
class _MediaFavorites extends ConsumerWidget {
  const _MediaFavorites({
    required this.categorySlug,
    required this.favoriteIds,
    required this.mediaKey,
  });

  final String categorySlug;
  final Set<String> favoriteIds;
  final String mediaKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mediaKey.isEmpty) return const _Empty();

    final media = ref.watch(mediaContentsByIdsProvider(mediaKey));

    return media.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => RetryView(
        onRetry: () => ref.invalidate(mediaContentsByIdsProvider(mediaKey)),
      ),
      data: (all) {
        final items = <MediaContent>[
          for (final item in all)
            if (item.categorySlug == categorySlug &&
                favoriteIds.contains('media:${item.id}'))
              item,
        ];
        if (items.isEmpty) return const _Empty();

        return _PagedList(
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _mediaRow(context, ref, items[index], items),
        );
      },
    );
  }
}
