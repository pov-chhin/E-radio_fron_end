import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/core/supports/tap_to_play.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/models/artist.dart';
import 'package:e_radio/data/models/category.dart';
import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/models/program.dart';
import 'package:e_radio/data/models/station.dart';
import 'package:e_radio/data/repositories/artist_repository.dart';
import 'package:e_radio/data/repositories/home_repository.dart';
import 'package:e_radio/data/repositories/category_repository.dart';
import 'package:e_radio/data/repositories/media_content_repository.dart';
import 'package:e_radio/data/repositories/program_repository.dart';
import 'package:e_radio/providers/station_provider.dart';
import 'package:e_radio/views/screens/explore/explore_view.dart';
import 'package:e_radio/views/widgets/explore/feed_card.dart';
import 'package:e_radio/views/widgets/explore/song_albums_section.dart';
import 'package:e_radio/views/widgets/explore/section_header.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'support/fake_media_list.dart';

import 'support/test_fonts.dart';

MediaContent _media(String id, String title, {String? artist, String? cat}) =>
    MediaContent(
      id: id,
      title: title,
      mediaType: 'audio',
      streamUrl: 'https://example.com/$id.mp3',
      artistName: artist,
      categoryName: cat,
    );

final _trending = [
  for (var i = 1; i <= 5; i++) _media('$i', 'Trending $i', artist: 'Artist $i'),
];
final _newReleases = [
  _media('11', 'Release One', artist: 'Release Artist'),
  _media('12', 'Release Two', artist: 'Release Artist'),
];
final _artistSongs = [
  for (var i = 1; i <= 4; i++)
    _media('s$i', 'Track $i', artist: 'G-Devith', cat: 'Song'),
  _media('s5', 'Other Track', artist: 'Tep Piseth', cat: 'Song'),
  _media('s6', 'Nameless Track', cat: 'Song'),
];
final _news = [
  _media('21', 'News Story One', cat: 'Reports'),
  _media('22', 'News Story Two', cat: 'Skills'),
  _media('23', 'News Story Three', cat: 'Events'),
];
const _shows = [
  Program(
    id: '7',
    name: 'Morning Brief',
    hostName: 'Sok Dara',
    categoryName: 'Podcast',
  ),
  Program(id: '8', name: 'Healthy Habits', categoryName: 'Health'),
];
const _categories = [
  Category(id: '1', name: 'News', slug: 'news'),
  Category(id: '2', name: 'Podcast', slug: 'podcast'),
];
const _station = Station(
  id: '1',
  name: 'Test Station',
  streamUrl: 'https://example.com/live.m3u8',
  tags: ['news'],
);

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

/// Records what it's asked to play instead of touching the audio platform.
class _FakePlayer extends AudioPlayerController {
  final played = <({NowPlayingItem item, List<NowPlayingItem>? queue})>[];

  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> play(
    NowPlayingItem item, {
    List<NowPlayingItem>? queue,
    int? queueIndex,
  }) async {
    played.add((item: item, queue: queue));
    state = PlaybackState(item: item, status: PlaybackStatus.playing);
  }
}

late _FakePlayer _player;

Future<void> _pump(
  WidgetTester tester, {
  List<MediaContent>? news,
  List<Program> programs = _shows,
  List<MediaContent> songs = const [],
  List<Artist> artists = const [],
  Map<String, Object> prefs = const {},
  double textScale = 1.0,
}) async {
  // Tall enough that every section is built (the list is lazy).
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  _player = _FakePlayer();
  final home = HomeData(
    trending: _trending,
    newReleases: _newReleases,
    feeds: {
      'news': news ?? _news,
      'economyfinance': const [],
      'health': const [],
      'song': songs,
    },
    programs: programs,
    categories: _categories,
    tags: const [],
    artists: artists,
  );

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(body: ExploreView()),
      ),
      for (final path in [
        '/stations',
        '/trending',
        '/new-release',
        '/library',
        '/podcasts',
        '/podcasts/7',
        '/music',
        '/now-playing',
      ])
        GoRoute(
          path: path,
          builder: (c, s) => Scaffold(body: Text('page $path')),
        ),
      GoRoute(
        path: '/category/:slug',
        builder: (c, s) =>
            Scaffold(body: Text('category ${s.pathParameters['slug']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        homeProvider.overrideWith(() => _FakeHome(home)),
        stationsProvider.overrideWith(_FakeStations.new),
        categoriesProvider.overrideWith((ref) async => _categories),
        trendingMediaContentsProvider.overrideWith((ref) async => _trending),
        trendingProgramMediaContentsProvider.overrideWith(
          () => FakeMediaList(_trending),
        ),
        newReleaseMediaContentsProvider.overrideWith(
          () => FakeMediaList(_newReleases),
        ),
        mediaContentsByCategoryProvider.overrideWith(
          (ref, slug) async => switch (slug) {
            'news' => news ?? _news,
            'song' => songs,
            _ => const [],
          },
        ),
        popularArtistsProvider.overrideWith((ref, tagIds) async => artists),
        programsProvider.overrideWith((ref) async => programs),
        mediaContentsByIdsProvider.overrideWith(
          (ref, ids) async => ids.isEmpty ? const [] : [_trending.first],
        ),
        audioPlayerControllerProvider.overrideWith(() => _player),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _headerOf(String title) => find.widgetWithText(SectionHeader, title);
Finder _seeAllOf(String title) =>
    find.descendant(of: _headerOf(title), matching: find.text('See All'));

void main() {
  setUpAll(loadTestFonts);
  setUp(resetTapToPlay);

  testWidgets('shows the sections in the designed order', (tester) async {
    await _pump(
      tester,
      songs: _artistSongs,
      prefs: {
        'recently_played_station_ids': ['station:1', 'media:1'],
      },
    );

    final titles = [
      'On Air',
      'Trending Programs',
      'New Releases',
      'Jump Back In',
      'News',
      'Podcast',
      'Song',
      'Ambient Music',
    ];
    final tops = [for (final t in titles) tester.getTopLeft(_headerOf(t)).dy];

    expect(tops, orderedEquals([...tops]..sort()), reason: '$titles at $tops');
    expect(tops.toSet(), hasLength(titles.length));
  });

  group('Trending Programs', () {
    testWidgets('shows three rows, with the next column peeking in', (
      tester,
    ) async {
      await _pump(tester);

      for (final n in [1, 2, 3]) {
        expect(find.text('Trending $n'), findsOneWidget);
      }
      // The second column is already built and its edge is on screen…
      final peek = tester.getTopLeft(find.text('Trending 4'));
      final screenWidth = tester.view.physicalSize.width / 2.625;
      expect(peek.dx, greaterThan(screenWidth * 0.85));

      // …and a swipe brings it fully into view.
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Trending 4')).dx, lessThan(100));
      expect(find.text('Trending 5'), findsOneWidget);
    });

    testWidgets('a section of three or fewer is one plain column', (
      tester,
    ) async {
      await _pump(tester);

      // Only Trending (five items) pages; New Releases (two) doesn't.
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Release One'), findsOneWidget);
      expect(find.text('Release Two'), findsOneWidget);
    });

    testWidgets('each row has a ⋮ instead of a play button', (tester) async {
      await _pump(tester);

      expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(7));
      expect(find.byIcon(Icons.play_circle_filled_rounded), findsNothing);
    });

    testWidgets('See All opens the full list', (tester) async {
      await _pump(tester);

      await tester.tap(_seeAllOf('Trending Programs'));
      await tester.pumpAndSettle();

      expect(find.text('page /trending'), findsOneWidget);
    });
  });

  group('a media row', () {
    testWidgets('plays when tapped, with the shown list as its queue', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Trending 2'));
      await tester.pump();

      expect(_player.played, hasLength(1));
      expect(_player.played.single.item.id, 'media:2');
      expect(_player.played.single.queue, hasLength(5));
    });

    testWidgets('a double tap plays it and opens Now Playing', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Trending 2'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Trending 2'));
      await tester.pumpAndSettle();

      expect(_player.played, hasLength(1));
      expect(find.text('page /now-playing'), findsOneWidget);
    });

    testWidgets('the ⋮ popup offers play, favorite and share', (tester) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Add to favorites'), findsOneWidget);
      expect(find.text('Add to bookmarks'), findsNothing);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('Play in the menu plays that row', (tester) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      expect(_player.played.single.item.id, 'media:1');
    });

    testWidgets('adding a favorite as a guest asks to sign in', (tester) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to favorites'));
      await tester.pumpAndSettle();

      expect(find.text('Log in to save your favorites'), findsOneWidget);
    });
  });

  group('Jump Back In', () {
    testWidgets('shows what was played, as compact cards', (tester) async {
      final playedAt = DateTime.now().subtract(const Duration(hours: 2));
      await _pump(
        tester,
        prefs: {
          'recently_played_station_ids': ['station:1', 'media:1'],
          'recently_played_at': jsonEncode({
            'station:1': playedAt.millisecondsSinceEpoch,
            'media:1': playedAt.millisecondsSinceEpoch,
          }),
        },
      );

      expect(_headerOf('Jump Back In'), findsOneWidget);
      // The station and the media item both appear (the media item also shows
      // in Trending, hence the widget-in-a-card lookup).
      final cards = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Material),
      );
      expect(cards, findsWidgets);
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('Test Station'),
        ),
        findsOneWidget,
      );
      expect(find.text('2 hours ago'), findsNWidgets(2));
    });

    testWidgets('a tap plays it', (tester) async {
      await _pump(
        tester,
        prefs: {
          'recently_played_station_ids': ['station:1'],
        },
      );

      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('Test Station'),
        ),
      );
      await tester.pump();

      // The time played is stamped by the real controller on every play, not
      // by the card — playback_progress_test covers that.
      expect(_player.played.single.item.id, 'station:1');
    });

    testWidgets('does not appear before anything has been played', (
      tester,
    ) async {
      await _pump(tester);

      expect(_headerOf('Jump Back In'), findsNothing);
    });
  });

  group('News', () {
    testWidgets('is a row of picture cards titled with the category', (
      tester,
    ) async {
      await _pump(tester);

      expect(_headerOf('News'), findsOneWidget);
      for (final title in ['News Story One', 'News Story Two']) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Reports'), findsOneWidget); // grey second line
    });

    testWidgets('a card grows with a large system font size instead of '
        'overflowing', (tester) async {
      await _pump(tester, textScale: 1.2);

      expect(tester.takeException(), isNull);
      // The picture keeps its 158; the row is taller by what the text grew.
      final card = find.ancestor(
        of: find.text('News Story One'),
        matching: find.byType(FeedCard),
      );
      final size = tester.getSize(card);
      expect(size.width, 158);
      expect(size.height, greaterThan(234));
    });

    testWidgets('See All opens the category', (tester) async {
      await _pump(tester);

      await tester.tap(_seeAllOf('News'));
      await tester.pumpAndSettle();

      expect(find.text('category news'), findsOneWidget);
    });

    testWidgets('a tap plays the story', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('News Story One'));
      await tester.pump();

      expect(_player.played.single.item.id, 'media:21');
      expect(_player.played.single.queue, hasLength(3));
    });

    testWidgets('has no row when the category is empty', (tester) async {
      await _pump(tester, news: const []);

      expect(_headerOf('News'), findsNothing);
      // The final Figma section remains available even when News is empty.
      expect(_headerOf('Ambient Music'), findsOneWidget);
    });
  });

  group('Podcast', () {
    testWidgets('is a row of shows titled with the category', (tester) async {
      await _pump(tester);

      expect(_headerOf('Podcast'), findsOneWidget);
      expect(find.text('Morning Brief'), findsOneWidget);
      expect(find.text('Healthy Habits'), findsOneWidget);
      expect(find.text('by Sok Dara • Podcast'), findsOneWidget);
    });

    testWidgets('sits between the news and the other categories', (
      tester,
    ) async {
      await _pump(tester);

      final news = tester.getTopLeft(_headerOf('News')).dy;
      final podcast = tester.getTopLeft(_headerOf('Podcast')).dy;
      final ambient = tester.getTopLeft(_headerOf('Ambient Music')).dy;
      expect(news, lessThan(podcast));
      expect(podcast, lessThan(ambient));
    });

    testWidgets('a tap opens the show', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Morning Brief'));
      await tester.pumpAndSettle();

      expect(find.text('page /podcasts/7'), findsOneWidget);
      expect(_player.played, isEmpty);
    });

    testWidgets('See All opens Podcast in the swipeable categories', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(_seeAllOf('Podcast'));
      await tester.pumpAndSettle();

      expect(find.text('category podcast'), findsOneWidget);
    });

    testWidgets('has no row while there are no shows', (tester) async {
      await _pump(tester, programs: const []);

      expect(_headerOf('Podcast'), findsNothing);
      expect(_headerOf('News'), findsOneWidget);
    });
  });

  group('Song', () {
    testWidgets('is a card per artist with their newest three songs', (
      tester,
    ) async {
      await _pump(tester, songs: _artistSongs);

      expect(_headerOf('Song'), findsOneWidget);
      expect(find.text('NEW RELEASE FROM'), findsNWidgets(3));
      expect(find.text('G-Devith'), findsOneWidget);
      expect(find.text('Tep Piseth'), findsOneWidget);
      // The fourth G-Devith track doesn't fit the card.
      for (final title in ['Track 1', 'Track 2', 'Track 3', 'Other Track']) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Track 4'), findsNothing);
      expect(find.text('by G-Devith'), findsNWidgets(3));
    });

    testWidgets('songs with no artist share a card under the app name', (
      tester,
    ) async {
      await _pump(tester, songs: _artistSongs);

      expect(find.text('e-Radio'), findsOneWidget);
      expect(find.text('Nameless Track'), findsOneWidget);
    });

    testWidgets('a card is 350 by 320, the next one peeking in', (
      tester,
    ) async {
      await _pump(tester, songs: _artistSongs);

      final card = find.ancestor(
        of: find.text('G-Devith'),
        matching: find.byType(ClipRRect),
      );
      expect(tester.getSize(card.first), const Size(350, 320));
      final second = tester.getTopLeft(
        find
            .ancestor(
              of: find.text('Tep Piseth'),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(second.dx, 20 + 350 + 12);
    });

    testWidgets('a card keeps its size, without overflowing, at a large system '
        'font size', (tester) async {
      // Past 1.14 the header alone is taller than the 48 it is given.
      await _pump(tester, songs: _artistSongs, textScale: 1.2);

      expect(tester.takeException(), isNull);
      final card = find.ancestor(
        of: find.text('G-Devith'),
        matching: find.byType(ClipRRect),
      );
      expect(tester.getSize(card.first), const Size(350, 320));
    });

    testWidgets("a row plays, with its card's songs as the queue", (
      tester,
    ) async {
      await _pump(tester, songs: _artistSongs);

      await tester.tap(find.text('Track 2'));
      await tester.pump();

      expect(_player.played.single.item.id, 'media:s2');
      expect(_player.played.single.queue, hasLength(3));
    });

    testWidgets('the ⋮ opens the options menu', (tester) async {
      await _pump(tester, songs: _artistSongs);

      final row = find
          .ancestor(of: find.text('Track 1'), matching: find.byType(InkWell))
          .first;
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('More options')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add to favorites'), findsOneWidget);
    });

    testWidgets('See All opens the Music page', (tester) async {
      await _pump(tester, songs: _artistSongs);

      await tester.tap(_seeAllOf('Song'));
      await tester.pumpAndSettle();

      expect(find.text('page /music'), findsOneWidget);
    });

    testWidgets('has no row while there are no songs', (tester) async {
      await _pump(tester);

      expect(_headerOf('Song'), findsNothing);
    });

    test('groups newest first, three songs and six artists at most', () {
      final songs = [
        for (var artist = 1; artist <= 8; artist++)
          for (var n = 1; n <= 4; n++)
            _media('$artist-$n', 'Song $artist-$n', artist: 'Artist $artist'),
      ];

      final albums = groupSongsByArtist(songs);

      expect(albums, hasLength(6));
      expect(
        [for (final a in albums) a.artistName],
        [for (var i = 1; i <= 6; i++) 'Artist $i'],
      );
      expect(albums.first.songs.map((s) => s.title), [
        'Song 1-1',
        'Song 1-2',
        'Song 1-3',
      ]);
    });
  });
}
