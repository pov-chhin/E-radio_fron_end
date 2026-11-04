import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/api_exception.dart';

import '../../../data/models/station.dart';
import '../../../data/repositories/home_repository.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../providers/connection_provider.dart';
import '../../../providers/station_provider.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/network_error_view.dart';
import '../../widgets/shared/no_internet_view.dart';
import '../../widgets/explore/categories_section.dart';
import '../../widgets/explore/category_feed_section.dart';
import '../../widgets/explore/discover_header.dart';
import '../../widgets/explore/explore_skeleton.dart';
import '../../widgets/explore/jump_back_in_section.dart';
import '../../widgets/explore/media_columns_section.dart';
import '../../widgets/explore/on_air_section.dart';
import '../../widgets/explore/podcast_feed_section.dart';
import '../../widgets/explore/song_albums_section.dart';

/// The home screen: live stations first, then what's trending, what's new,
/// where the person left off, a news feed, and every category to browse.
class ExploreView extends ConsumerWidget {
  const ExploreView({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    final stations = ref.read(stationsProvider.notifier).refresh();
    final home = ref.read(homeProvider.notifier).refresh();
    await Future.wait([stations, home]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stations = ref.watch(stationsProvider);
    final home = ref.watch(homeProvider).asData?.value;

    // Nothing has loaded yet: the whole page as grey placeholders — the header
    // included — while it's on its way.
    if (!stations.hasValue && stations.isLoading) {
      return const SafeArea(bottom: false, child: ExploreSkeleton());
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const DiscoverHeader(),
          Expanded(child: _body(context, ref, l10n, stations, home)),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<List<Station>> stations,
    HomeData? home,
  ) {
    // Nothing has loaded and it isn't on its way: if the server can't be
    // reached at all (an answer, even an error one, would be an ApiException),
    // a page saying so — "No Internet Connection" when the phone is offline,
    // "Connection Lost" when it is only the server.
    if (!stations.hasValue) {
      if (stations.hasError && stations.error is! ApiException) {
        if (!ref.watch(connectionStatusProvider)) {
          return NoInternetView(
            onRetry: () => ref.read(stationsProvider.notifier).refresh(),
          );
        }
        return NetworkErrorView(
          onRetry: () => ref.read(stationsProvider.notifier).refresh(),
          onGoOffline: () => context.push('/library'),
        );
      }
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        children: [
          const OnAirSection(),
          if (home != null) ...[
            MediaColumnsSection(
              title: l10n.trendingProgram,
              provider: trendingProgramMediaContentsProvider,
              seeAllPath: '/trending',
              items: home.trending,
            ),
            MediaColumnsSection(
              title: l10n.newRelease,
              provider: newReleaseMediaContentsProvider,
              seeAllPath: '/new-release',
              items: home.newReleases,
            ),
          ],
          const JumpBackInSection(),
          if (home != null) ...[
            CategoryFeedSection(
              slug: 'news',
              items: home.feeds['news'],
              categories: home.categories,
            ),
            CategoryFeedSection(
              slug: 'economyfinance',
              items: home.feeds['economyfinance'],
              categories: home.categories,
            ),
            PodcastFeedSection(
              programs: home.programs,
              categories: home.categories,
            ),
            CategoryFeedSection(
              slug: 'health',
              items: home.feeds['health'],
              categories: home.categories,
            ),
            SongAlbumsSection(songs: home.feeds['song'], artists: home.artists),
            CategoriesSection(tags: home.tags),
          ],
        ],
      ),
    );
  }
}
