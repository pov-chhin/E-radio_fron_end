import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/core/supports/tap_to_play.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/views/themes/app_colors.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/core/router/app_router.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/models/artist.dart';
import 'package:e_radio/data/models/category.dart';
import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/models/program.dart';
import 'package:e_radio/data/models/station.dart';
import 'package:e_radio/data/models/tag.dart';
import 'package:e_radio/data/repositories/artist_repository.dart';
import 'package:e_radio/data/repositories/home_repository.dart';
import 'package:e_radio/data/repositories/category_repository.dart';
import 'package:e_radio/data/repositories/media_content_repository.dart';
import 'package:e_radio/data/repositories/program_repository.dart';
import 'package:e_radio/providers/station_provider.dart';
import 'package:e_radio/data/repositories/tag_repository.dart';
import 'package:e_radio/views/screens/category/category_view.dart';
import 'package:e_radio/views/screens/explore/all_stations_view.dart';
import 'package:e_radio/views/screens/explore/explore_view.dart';
import 'package:e_radio/views/screens/explore/jump_back_in_view.dart';
import 'package:e_radio/views/screens/explore/media_feed_view.dart';
import 'package:e_radio/views/widgets/explore/discover_header.dart';
import 'package:e_radio/views/screens/favorites/favorites_view.dart';
import 'package:e_radio/views/screens/music/ambient_music_view.dart';
import 'package:e_radio/views/screens/music/music_view.dart';
import 'package:e_radio/views/screens/notifications/notifications_inbox_view.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/views/screens/podcasts/podcast_show_view.dart';
import 'package:e_radio/views/screens/podcasts/podcasts_view.dart';
import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/data/models/user_profile.dart';
import 'package:e_radio/views/screens/search/search_view.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/views/widgets/shared/app_navigation_bar.dart';
import 'package:e_radio/views/widgets/shared/filter_pill.dart';
import 'package:e_radio/views/widgets/shared/see_all_header.dart';
import 'support/fake_media_list.dart';

import 'support/test_fonts.dart';

final _profile = UserProfile(
  id: '1',
  firstName: 'Sok',
  lastName: 'Dara',
  email: 'sok@example.com',
  joinedAt: DateTime(2026, 9, 28),
);

const _station = Station(
  id: '1',
  name: 'Test Station',
  streamUrl: 'https://example.com/live.m3u8',
  tags: ['news'],
);
const _categories = [
  Category(id: '1', name: 'News', slug: 'news'),
  Category(id: '2', name: 'Podcast', slug: 'podcast'),
  Category(id: '3', name: 'Song', slug: 'song'),
];
const _show = Program(
  id: '7',
  name: 'Morning Brief',
  hostName: 'Sok Dara',
  categoryName: 'Podcast',
  episodes: [
    MediaContent(
      id: '70',
      title: 'Pilot Episode',
      mediaType: 'audio',
      streamUrl: 'https://example.com/pilot.mp3',
    ),
  ],
);
final _songs = [
  for (var i = 1; i <= 3; i++)
    MediaContent(
      id: 's$i',
      title: 'Song $i',
      mediaType: 'audio',
      streamUrl: 'https://example.com/s$i.mp3',
      artistName: 'G-Devith',
    ),
];

class _FakeAuth extends AuthController {
  @override
  UserProfile? build() => _profile;
}

class _FakeStations extends StationsNotifier {
  @override
  Future<List<Station>> build() async => const [_station];
}

class _FakeHome extends HomeNotifier {
  _FakeHome(this.data);

  final HomeData data;

  @override
  HomeData build() => data;
}

class _FakePlayer extends AudioPlayerController {
  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> play(
    NowPlayingItem item, {
    List<NowPlayingItem>? queue,
    int? queueIndex,
  }) async {}
}

late GoRouter _router;

/// The real router and shell, with every provider a tab reads answered locally.
MediaContent _story(String id, String title) => MediaContent(
  id: id,
  title: title,
  mediaType: 'audio',
  streamUrl: 'https://example.com/$id.mp3',
  categoryName: 'News',
);

/// How many times the tag list has been asked for.
var _tagFetches = 0;

Future<void> _pump(
  WidgetTester tester, {
  List<MediaContent> trending = const [],
  List<MediaContent> news = const [],
  List<Tag> tags = const [],
  Map<String, List<MediaContent>> byTag = const {},
}) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
  final prefs = await SharedPreferences.getInstance();
  final home = HomeData(
    trending: trending,
    newReleases: const [],
    feeds: {
      'news': news,
      'economyfinance': const [],
      'health': const [],
      'song': _songs,
    },
    programs: const [_show],
    categories: _categories,
    tags: tags,
    artists: const [],
  );

  await tester.pumpWidget(
    ProviderScope(
      retry: (count, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        homeProvider.overrideWith(() => _FakeHome(home)),
        authControllerProvider.overrideWith(_FakeAuth.new),
        stationsProvider.overrideWith(_FakeStations.new),
        categoriesProvider.overrideWith((ref) async => _categories),
        trendingMediaContentsProvider.overrideWith((ref) async => trending),
        trendingProgramMediaContentsProvider.overrideWith(
          () => FakeMediaList(trending),
        ),
        newReleaseMediaContentsProvider.overrideWith(
          () => FakeMediaList(const []),
        ),
        mediaContentsByCategoryProvider.overrideWith(
          (ref, slug) async => switch (slug) {
            'song' => _songs,
            'news' => news,
            _ => const [],
          },
        ),
        mediaContentsByTagProvider.overrideWith(
          (ref, id) async => byTag[id] ?? const [],
        ),
        mediaContentsByIdsProvider.overrideWith((ref, ids) async => const []),
        programsProvider.overrideWith((ref) async => const [_show]),
        programsByTagProvider.overrideWith((ref, id) async => const [_show]),
        programProvider.overrideWith((ref, id) async => _show),
        tagsProvider.overrideWith((ref) async {
          _tagFetches++;
          return tags;
        }),
        popularArtistsProvider.overrideWith(
          (ref, tagIds) async => const <Artist>[],
        ),
        popularSongsProvider.overrideWith((ref, filter) async => _songs),
        audioPlayerControllerProvider.overrideWith(_FakePlayer.new),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          _router = ref.watch(appRouterProvider);
          return MaterialApp.router(
            routerConfig: _router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The "See All" beside a section's title.
Finder _seeAll(String title) => find.descendant(
  of: find.widgetWithText(Row, title),
  matching: find.text('See All'),
);

Finder _navLabel(String label) => find.descendant(
  of: find.byType(AppNavigationBar),
  matching: find.text(label),
);

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(_navLabel(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() {
    resetTapToPlay();
    _tagFetches = 0;
  });

  group('the bottom bar', () {
    testWidgets('has Discover, Podcasts, Music and Favorites', (tester) async {
      await _pump(tester);

      expect(find.byType(ExploreView), findsOneWidget);
      for (final label in ['Discover', 'Podcasts', 'Music', 'Favorites']) {
        expect(_navLabel(label), findsOneWidget);
      }
      expect(_navLabel('Search'), findsNothing);
      expect(_navLabel('Library'), findsNothing);
    });

    testWidgets('asks for the tags again when the app comes back, so pictures '
        'changed in the admin show up', (tester) async {
      await _pump(tester);
      final before = _tagFetches;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(_tagFetches, greaterThan(before));
    });

    testWidgets('draws the picked tab in the brand violet', (tester) async {
      await _pump(tester);

      Color? colorOf(String label) =>
          tester.widget<Text>(_navLabel(label)).style?.color;

      expect(colorOf('Discover'), AppColors.brand400);
      expect(colorOf('Music'), isNot(AppColors.brand400));

      await _tapTab(tester, 'Music');

      expect(colorOf('Music'), AppColors.brand400);
      expect(colorOf('Discover'), isNot(AppColors.brand400));
    });

    testWidgets('is 110px tall, with the buttons 72 by 54', (tester) async {
      await _pump(tester);

      expect(tester.getSize(find.byType(AppNavigationBar)).height, 110);
      final button = find.ancestor(
        of: _navLabel('Podcasts'),
        matching: find.byType(SizedBox),
      );
      expect(
        button.evaluate().map((e) => tester.getSize(find.byWidget(e.widget))),
        contains(const Size(72, 54)),
      );
    });

    testWidgets('switches between the four pages', (tester) async {
      await _pump(tester);

      await _tapTab(tester, 'Podcasts');
      expect(find.byType(PodcastsView), findsOneWidget);
      expect(find.byType(DiscoverHeader), findsNothing);

      await _tapTab(tester, 'Music');
      expect(find.byType(MusicView), findsOneWidget);
      expect(find.byType(DiscoverHeader), findsNothing);

      await _tapTab(tester, 'Favorites');
      expect(find.byType(FavoritesView), findsOneWidget);
      expect(find.byType(DiscoverHeader), findsNothing);

      await _tapTab(tester, 'Discover');
      expect(find.byType(ExploreView), findsOneWidget);
      expect(find.byType(DiscoverHeader), findsOneWidget);
    });

    testWidgets('stays under a show and under Ambient Music', (tester) async {
      await _pump(tester);

      _router.go('/podcasts/7');
      await tester.pumpAndSettle();
      expect(find.byType(PodcastShowView), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsOneWidget);

      _router.go('/music/ambient');
      await tester.pumpAndSettle();
      expect(find.byType(AmbientMusicView), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsOneWidget);
    });
  });

  group('the Discover header', () {
    testWidgets('greets the person and has a magnifier and a bell', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Sok'), findsOneWidget);
      expect(find.byTooltip('Search'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });

    testWidgets('the icons are 20px, 36px apart, 20px in from the edge', (
      tester,
    ) async {
      await _pump(tester);

      final search = tester.getCenter(find.byTooltip('Search'));
      final bell = tester.getCenter(find.byTooltip('Notifications'));
      expect(bell.dx - search.dx, 36);
      // The bell's 20px icon ends 20px from the right edge (390 - 20 - 10).
      expect(bell.dx, 360);
    });

    testWidgets('the magnifier opens Search under the tab bar', (tester) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchView), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsOneWidget);
      // Discover stays the lit tab.
      expect(
        tester.widget<Text>(_navLabel('Discover')).style?.color,
        AppColors.brand400,
      );
    });

    testWidgets('the bell opens the notifications page', (tester) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsInboxView), findsOneWidget);
    });
  });

  group('jumping between tabs', () {
    testWidgets('a Home podcast card opens the show under the bar', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Morning Brief'));
      await tester.pumpAndSettle();

      expect(find.byType(PodcastShowView), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsOneWidget);
    });

    testWidgets("Song's See All switches to the Music tab", (tester) async {
      await _pump(tester);

      final seeAll = find.descendant(
        of: find.widgetWithText(Row, 'Song'),
        matching: find.text('See All'),
      );
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();

      expect(find.byType(MusicView), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsOneWidget);
    });

    testWidgets("Ambient Music's See All opens Ambient Music, not Podcasts", (
      tester,
    ) async {
      await _pump(tester);

      // The last section of a list that is only built as it scrolls into view.
      await tester.scrollUntilVisible(
        find.text('Ambient Music'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ExploreView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final seeAll = find.descendant(
        of: find.widgetWithText(Row, 'Ambient Music'),
        matching: find.text('See All'),
      );
      await tester.tap(seeAll);
      await tester.pumpAndSettle();

      expect(find.byType(AmbientMusicView), findsOneWidget);
      expect(find.byType(PodcastsView), findsNothing);
      expect(find.byType(AppNavigationBar), findsOneWidget);
    });

    testWidgets('podcast uses the category design; song lands on its tab', (
      tester,
    ) async {
      await _pump(tester);

      _router.go('/category/podcast');
      await tester.pumpAndSettle();
      expect(find.byType(CategoryView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SeeAllHeader),
          matching: find.text('Podcast'),
        ),
        findsOneWidget,
      );

      _router.go('/category/song');
      await tester.pumpAndSettle();
      expect(find.byType(MusicView), findsOneWidget);
    });
  });

  group('the pages that open from Discover', () {
    Future<void> open(WidgetTester tester, String location) async {
      unawaited(_router.push(location));
      await tester.pumpAndSettle();
    }

    testWidgets('keep the tab bar, with Discover lit', (tester) async {
      await _pump(tester);

      for (final location in [
        '/trending',
        '/new-release',
        '/library',
        '/stations',
        '/notifications',
        '/category/news',
      ]) {
        await open(tester, location);
        expect(find.byType(AppNavigationBar), findsOneWidget, reason: location);
        expect(
          tester.widget<Text>(_navLabel('Discover')).style?.color,
          AppColors.brand400,
          reason: location,
        );
        // A page of its own on top of Home: it has its back arrow, not Home's greeting.
        expect(find.byType(DiscoverHeader).hitTestable(), findsNothing);
        _router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(ExploreView), findsOneWidget);
      }
    });

    testWidgets(
      'Trending Programs: a back arrow, the title centred, the rows',
      (tester) async {
        await _pump(
          tester,
          trending: [_story('1', 'First Story'), _story('2', 'Second Story')],
        );

        await tester.tap(_seeAll('Trending Programs'));
        await tester.pumpAndSettle();

        expect(find.byType(MediaFeedView), findsOneWidget);
        final header = find.byType(SeeAllHeader);
        expect(tester.getSize(header).height, 48);
        final title = find.descendant(
          of: header,
          matching: find.text('Trending Programs'),
        );
        expect(tester.getCenter(title).dx, closeTo(195, 6));
        expect(find.text('First Story'), findsWidgets);
        expect(find.text('Second Story'), findsWidgets);

        // The arrow goes back to Discover.
        await tester.tap(
          find.descendant(of: header, matching: find.byType(InkResponse)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExploreView), findsOneWidget);
      },
    );

    testWidgets('On Air Now: the hero card over All Stations', (tester) async {
      await _pump(tester);

      await tester.tap(_seeAll('On Air'));
      await tester.pumpAndSettle();

      expect(find.byType(AllStationsView), findsOneWidget);
      expect(find.text('On Air Now'), findsOneWidget);
      expect(find.text('All Stations'), findsOneWidget);
      expect(find.text('• LIVE'), findsOneWidget);
      // The station is the hero and the first row.
      expect(find.text('Test Station'), findsNWidgets(2));
      expect(find.byTooltip('More options'), findsOneWidget);
    });

    testWidgets('the ⋮ on a station row offers play, favorites and share', (
      tester,
    ) async {
      await _pump(tester);
      await open(tester, '/stations');

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Add to favorites'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('Jump Back In says so when nothing was played', (tester) async {
      await _pump(tester);

      await open(tester, '/library');

      expect(find.byType(JumpBackInView), findsOneWidget);
      expect(find.text('Jump Back In'), findsOneWidget);
      expect(find.text('Nothing played yet'), findsOneWidget);
    });

    testWidgets(
      'a category: All and its tags as pills, the stories as a grid',
      (tester) async {
        final politic = const Tag(id: '14', name: 'Politic', slug: 'politic');
        await _pump(
          tester,
          news: [
            _story('1', 'Story One'),
            _story('2', 'Story Two'),
            _story('3', 'Story Three'),
          ],
          tags: [
            Tag(
              id: '13',
              name: 'News',
              slug: 'news',
              children: [
                politic,
                const Tag(id: '17', name: 'Sports', slug: 'sports'),
              ],
            ),
          ],
          byTag: {
            '14': [_story('9', 'Election Story')],
          },
        );
        await open(tester, '/category/news');

        expect(find.byType(CategoryView), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SeeAllHeader),
            matching: find.text('News'),
          ),
          findsOneWidget,
        );
        for (final label in ['All', 'Politic', 'Sports']) {
          expect(
            find.descendant(
              of: find.byType(FilterPillRow),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
        }
        // Two 158-wide cards a row, centred in their halves: x 25.5 and 206.5.
        expect(tester.getTopLeft(find.text('Story One')).dx, closeTo(25.5, .5));
        expect(
          tester.getTopLeft(find.text('Story Two')).dx,
          closeTo(206.5, .5),
        );
        expect(
          tester.getTopLeft(find.text('Story Three')).dx,
          closeTo(25.5, .5),
        );

        // A pill narrows the grid in place.
        await tester.tap(
          find.descendant(
            of: find.byType(FilterPillRow),
            matching: find.text('Politic'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Election Story'), findsOneWidget);
        expect(find.text('Story One'), findsNothing);

        await tester.tap(
          find.descendant(
            of: find.byType(FilterPillRow),
            matching: find.text('All'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Story One'), findsOneWidget);

        // Swiping the content selects the next filter pill too.
        await tester.fling(find.byType(PageView), const Offset(-350, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text('Election Story'), findsOneWidget);
        expect(find.text('Story One'), findsNothing);
      },
    );

    testWidgets('Notifications keeps its empty state under the same header', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsInboxView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SeeAllHeader),
          matching: find.text('Notifications'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the station list opens under Discover from any other tab', (
      tester,
    ) async {
      await _pump(tester);
      await _tapTab(tester, 'Music');

      _router.go('/stations');
      await tester.pumpAndSettle();

      expect(find.byType(AllStationsView), findsOneWidget);
      expect(find.byType(AppNavigationBar), findsOneWidget);
      expect(
        tester.widget<Text>(_navLabel('Discover')).style?.color,
        AppColors.brand400,
      );
    });
  });
}
