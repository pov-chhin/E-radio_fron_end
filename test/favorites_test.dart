import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/core/supports/tap_to_play.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/models/category.dart';
import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/models/station.dart';
import 'package:e_radio/data/repositories/category_repository.dart';
import 'package:e_radio/data/repositories/media_content_repository.dart';
import 'package:e_radio/providers/station_provider.dart';
import 'package:e_radio/providers/favorites_provider.dart';
import 'package:e_radio/views/screens/favorites/favorites_view.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/data/models/user_profile.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';

import 'support/test_fonts.dart';

const _categories = [
  Category(id: '1', name: 'Podcast', slug: 'podcast'),
  Category(id: '2', name: 'News', slug: 'news'),
  Category(id: '3', name: 'Health', slug: 'health'),
  Category(id: '4', name: 'Economy/Finance', slug: 'economyfinance'),
  Category(id: '5', name: 'Song', slug: 'song'),
  Category(id: '6', name: 'Ambient Music', slug: 'ambient-music'),
];

const _stations = [
  Station(
    id: '1',
    name: 'Khmer Times',
    streamUrl: 'https://example.com/1.m3u8',
    description: 'Sat 8:00 - 9:00',
  ),
  Station(
    id: '2',
    name: 'Not A Favorite',
    streamUrl: 'https://example.com/2.m3u8',
  ),
  Station(
    id: '3',
    name: 'Morning FM',
    streamUrl: 'https://example.com/3.m3u8',
    tags: ['pop', 'morning'],
  ),
];

MediaContent _media(String id, String title, String slug, {String? artist}) =>
    MediaContent(
      id: id,
      title: title,
      mediaType: 'audio',
      streamUrl: 'https://example.com/$id.mp3',
      categorySlug: slug,
      categoryName: slug,
      artistName: artist,
    );

final _catalog = [
  _media('11', 'In Between Us', 'song', artist: 'Suly Pheng'),
  _media('12', 'Waves of Serenity', 'song', artist: 'Nature Sounds'),
  _media('13', 'Cambodia and Japan Talks', 'news'),
  _media('14', 'Not Saved', 'song'),
];

final _profile = UserProfile(
  id: '1',
  firstName: 'Sok',
  lastName: 'Dara',
  email: 'sok@example.com',
  joinedAt: DateTime(2026, 9, 28),
);

class _FakeAuth extends AuthController {
  _FakeAuth(this.profile);

  final UserProfile? profile;

  @override
  UserProfile? build() => profile;
}

class _FakeStations extends StationsNotifier {
  _FakeStations(this.stations);

  final List<Station> stations;

  @override
  Future<List<Station>> build() async => stations;
}

/// Records what it's asked to play instead of touching the audio platform.
class _FakePlayer extends AudioPlayerController {
  final played = <NowPlayingItem>[];

  @override
  PlaybackState build() => const PlaybackState();

  @override
  Future<void> play(
    NowPlayingItem item, {
    List<NowPlayingItem>? queue,
    int? queueIndex,
  }) async {
    played.add(item);
  }
}

late _FakePlayer _player;
late SharedPreferences _prefs;
final lookups = <String>[];

Future<void> _pump(
  WidgetTester tester, {
  bool signedIn = true,
  List<String> favorites = const [
    'station:1',
    'station:3',
    'media:11',
    'media:12',
    'media:13',
  ],
  List<Station> stations = _stations,
  Widget home = const FavoritesView(),
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'favorite_station_ids': favorites});
  _prefs = await SharedPreferences.getInstance();
  _player = _FakePlayer();
  lookups.clear();

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => Scaffold(body: home),
      ),
      GoRoute(
        path: '/profile/login',
        builder: (c, s) => const Scaffold(body: Text('login page')),
      ),
      GoRoute(
        path: '/explore',
        builder: (c, s) => const Scaffold(body: Text('explore page')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs),
        authControllerProvider.overrideWith(
          () => _FakeAuth(signedIn ? _profile : null),
        ),
        stationsProvider.overrideWith(() => _FakeStations(stations)),
        categoriesProvider.overrideWith((ref) async => _categories),
        mediaContentsByIdsProvider.overrideWith((ref, ids) async {
          lookups.add(ids);
          final wanted = ids.split(',').toSet();
          return [
            for (final item in _catalog)
              if (wanted.contains(item.id)) item,
          ];
        }),
        audioPlayerControllerProvider.overrideWith(() => _player),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _violet = Color(0xFF8B5CF6);

Color _fillOf(WidgetTester tester, String label) => tester
    .widget<Material>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first,
    )
    .color!;

/// Taps a pill, scrolling the row first if it's past the screen edge.
Future<void> _pick(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Set<String> _saved() => _prefs.getStringList('favorite_station_ids')!.toSet();

void main() {
  setUpAll(loadTestFonts);
  setUp(resetTapToPlay);

  group('as a guest', () {
    testWidgets('shows the title and asks to sign in', (tester) async {
      await _pump(tester, signedIn: false);

      expect(find.text('Favorites'), findsOneWidget);
      expect(
        find.text('Sign in to save favorites and sync your profile'),
        findsOneWidget,
      );
      // No pills and no rows.
      expect(find.text('Radio'), findsNothing);
      expect(find.text('Khmer Times'), findsNothing);
    });

    testWidgets('Sign In opens the login page', (tester) async {
      await _pump(tester, signedIn: false);

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('login page'), findsOneWidget);
    });
  });

  group('when nothing is saved anywhere', () {
    testWidgets('shows the empty page instead of pills', (tester) async {
      await _pump(tester, favorites: const []);

      expect(find.text('Favorites'), findsOneWidget); // the header's title
      expect(find.text('No favorites yet'), findsOneWidget);
      expect(
        find.text(
          'Save your favorite stations, songs, podcasts and stories to find '
          'them here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Explore Content'), findsOneWidget);
      // No pills, since there is nothing to group.
      expect(find.text('Radio'), findsNothing);
      expect(find.text('Podcast'), findsNothing);
    });

    testWidgets('draws the badge and button as designed', (tester) async {
      await _pump(tester, favorites: const []);

      final badge = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0xFFECE5FF),
      );
      expect(tester.getSize(badge), const Size(120, 120));
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Explore Content'),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .width,
        200,
      );
      // The header is a back arrow with the title centred.
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(tester.getCenter(find.text('Favorites')).dx, closeTo(195, 3));
    });

    testWidgets('Explore Content and the back arrow go to Discover', (
      tester,
    ) async {
      await _pump(tester, favorites: const []);
      await tester.tap(find.text('Explore Content'));
      await tester.pumpAndSettle();
      expect(find.text('explore page'), findsOneWidget);

      await _pump(tester, favorites: const []);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('explore page'), findsOneWidget);
    });

    testWidgets('and saving one brings the pills back', (tester) async {
      await _pump(tester, favorites: const []);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FavoritesView)),
      );
      container.read(favoritesProvider.notifier).toggle('station:1');
      await tester.pumpAndSettle();

      expect(find.text('Radio'), findsOneWidget);
      expect(find.text('Khmer Times'), findsOneWidget);
    });
  });

  group('the pills', () {
    testWidgets('are All, Radio, then every category', (tester) async {
      await _pump(tester);

      final labels = [
        'All',
        'Radio',
        'Podcast',
        'News',
        'Health',
        'Economy/Finance',
        'Song',
        'Ambient Music',
      ];
      final lefts = [
        for (final label in labels) tester.getTopLeft(find.text(label)).dx,
      ];
      expect(lefts, orderedEquals([...lefts]..sort()));
    });

    testWidgets('open on All, in violet', (tester) async {
      await _pump(tester);

      expect(_fillOf(tester, 'All'), _violet);
      expect(_fillOf(tester, 'Radio'), Colors.white);
      expect(_fillOf(tester, 'Podcast'), Colors.white);
    });
  });

  group('swiping the list sideways', () {
    Future<void> swipe(WidgetTester tester, {required bool left}) async {
      await tester.fling(
        find.byType(PageView),
        Offset(left ? -300 : 300, 0),
        1000,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('left moves to the next pill, right to the one before', (
      tester,
    ) async {
      await _pump(tester);

      await swipe(tester, left: true);
      expect(_fillOf(tester, 'Radio'), _violet);
      expect(_fillOf(tester, 'All'), Colors.white);
      expect(find.text('In Between Us'), findsNothing);

      await swipe(tester, left: true);
      expect(_fillOf(tester, 'Podcast'), _violet);

      await swipe(tester, left: false);
      await swipe(tester, left: false);
      expect(_fillOf(tester, 'All'), _violet);
      expect(find.text('In Between Us'), findsOneWidget);
    });

    testWidgets('right on All stays on All', (tester) async {
      await _pump(tester);

      await swipe(tester, left: false);

      expect(_fillOf(tester, 'All'), _violet);
      expect(find.text('Khmer Times'), findsOneWidget);
    });

    testWidgets('lands on the category and shows its favorites', (
      tester,
    ) async {
      await _pump(tester);

      await _pick(tester, 'Song');
      await swipe(tester, left: false);

      expect(_fillOf(tester, 'Economy/Finance'), _violet);
    });
  });

  group('a long list', () {
    final many = [
      for (var i = 1; i <= 45; i++)
        Station(
          id: '$i',
          name: 'Station $i',
          streamUrl: 'https://example.com/$i.m3u8',
        ),
    ];

    /// The rows in the list: it counts a separator between each two.
    int rows(WidgetTester tester) =>
        ((tester.widget<ListView>(find.byType(ListView)).childrenDelegate
                    as SliverChildBuilderDelegate)
                .childCount! +
            1) ~/
        2;

    Future<void> swipeUp(WidgetTester tester) async {
      // A drag, not a fling: a fling's momentum would carry on into the rows
      // that the swipe has just added.
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
    }

    testWidgets('shows 20 first, then 20 more at each swipe up', (
      tester,
    ) async {
      await _pump(
        tester,
        stations: many,
        favorites: [for (final s in many) 'station:${s.id}'],
      );
      await _pick(tester, 'Radio');
      expect(rows(tester), 20);
      expect(find.text('Station 1'), findsOneWidget);

      await swipeUp(tester);
      expect(rows(tester), 40);

      await swipeUp(tester);
      expect(rows(tester), 45);
      await swipeUp(tester);
      expect(rows(tester), 45);
    });

    testWidgets('All pages the same way', (tester) async {
      await _pump(
        tester,
        stations: many,
        favorites: [for (final s in many) 'station:${s.id}'],
      );
      expect(rows(tester), 20);

      await swipeUp(tester);
      expect(rows(tester), 40);
    });

    testWidgets('a short list is shown whole', (tester) async {
      await _pump(tester);
      await _pick(tester, 'Radio');

      expect(rows(tester), 2);
    });
  });

  group('All', () {
    testWidgets('lists every favorite: stations first, then the rest', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Khmer Times'), findsOneWidget);
      expect(find.text('Morning FM'), findsOneWidget);
      expect(find.text('In Between Us'), findsOneWidget);
      expect(find.text('Waves of Serenity'), findsOneWidget);
      expect(find.text('Cambodia and Japan Talks'), findsOneWidget);
      // Never saved.
      expect(find.text('Not A Favorite'), findsNothing);
      expect(find.text('Not Saved'), findsNothing);

      final tops = [
        for (final title in [
          'Khmer Times',
          'Morning FM',
          'In Between Us',
          'Waves of Serenity',
          'Cambodia and Japan Talks',
        ])
          tester.getTopLeft(find.text(title)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
    });

    testWidgets('with only stations saved, asks the catalog for nothing', (
      tester,
    ) async {
      await _pump(tester, favorites: const ['station:1']);

      expect(find.text('Khmer Times'), findsOneWidget);
      expect(lookups, isEmpty);
    });

    testWidgets('a tap plays a station or a song', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Khmer Times'));
      await tester.pump();
      await tester.tap(find.text('Waves of Serenity'));
      await tester.pump();

      expect(_player.played.map((item) => item.id), ['station:1', 'media:12']);
    });

    testWidgets('removing one from here saves the change', (tester) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.more_vert_rounded).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from favorites'));
      await tester.pumpAndSettle();

      expect(find.text('In Between Us'), findsNothing);
      expect(find.text('Khmer Times'), findsOneWidget);
      expect(_saved(), isNot(contains('media:11')));
      expect(lookups, hasLength(1));
    });

    testWidgets('says so when the catalog has none of them', (tester) async {
      await _pump(tester, favorites: const ['media:99']);

      expect(find.text('No favorites yet'), findsOneWidget);
    });
  });

  group('Radio', () {
    testWidgets('lists the favorite stations only', (tester) async {
      await _pump(tester);
      await _pick(tester, 'Radio');

      expect(find.text('Khmer Times'), findsOneWidget);
      expect(find.text('Morning FM'), findsOneWidget);
      expect(find.text('Not A Favorite'), findsNothing);
      expect(find.text('In Between Us'), findsNothing);
      // A grey second line: the description, else the tags.
      expect(find.text('Sat 8:00 - 9:00'), findsOneWidget);
      expect(find.text('pop, morning'), findsOneWidget);
    });

    testWidgets('rows follow the design: 56 picture, 12 gap, 8 apart', (
      tester,
    ) async {
      await _pump(tester);
      await _pick(tester, 'Radio');

      final first = tester.getTopLeft(find.text('Khmer Times'));
      final second = tester.getTopLeft(find.text('Morning FM'));
      // 20 margin + 56 picture + 12 gap.
      expect(first.dx, 20 + 56 + 12);
      // Rows are 56 tall with 8 between them.
      expect(second.dy - first.dy, closeTo(56 + 8, 1));
      // A title gets 240 of a 344-wide row.
      final titleWidth = tester
          .getSize(
            find
                .ancestor(
                  of: find.text('Khmer Times'),
                  matching: find.byType(Column),
                )
                .first,
          )
          .width;
      expect(titleWidth, 240);
    });

    testWidgets('a tap plays the station', (tester) async {
      await _pump(tester);
      await _pick(tester, 'Radio');

      await tester.tap(find.text('Khmer Times'));
      await tester.pump();

      expect(_player.played.single.id, 'station:1');
    });

    testWidgets('says so when there are none', (tester) async {
      await _pump(tester, favorites: const ['media:11']);
      await _pick(tester, 'Radio');

      expect(find.text('No favorites yet'), findsOneWidget);
    });
  });

  group('a category', () {
    testWidgets('lists the favorites in it, and only those', (tester) async {
      await _pump(tester);

      await _pick(tester, 'Song');

      expect(find.text('In Between Us'), findsOneWidget);
      expect(find.text('Waves of Serenity'), findsOneWidget);
      // Saved, but a news story; and a song that was never saved.
      expect(find.text('Cambodia and Japan Talks'), findsNothing);
      expect(find.text('Not Saved'), findsNothing);
      expect(find.text('Suly Pheng'), findsOneWidget);
      expect(_fillOf(tester, 'Song'), _violet);
      expect(_fillOf(tester, 'Radio'), Colors.white);
    });

    testWidgets('one lookup covers every category', (tester) async {
      await _pump(tester);

      await _pick(tester, 'Song');
      await _pick(tester, 'News');

      expect(find.text('Cambodia and Japan Talks'), findsOneWidget);
      expect(lookups, ['11,12,13']);
    });

    testWidgets('says so when it has none', (tester) async {
      await _pump(tester);

      await _pick(tester, 'Health');

      expect(find.text('No favorites yet'), findsOneWidget);
    });

    testWidgets('a tap plays the item with the group as its queue', (
      tester,
    ) async {
      await _pump(tester);

      await _pick(tester, 'Song');
      await tester.tap(find.text('Waves of Serenity'));
      await tester.pump();

      expect(_player.played.single.id, 'media:12');
    });
  });

  group('the ⋮ menu', () {
    Finder dots() => find.byIcon(Icons.more_vert_rounded);

    testWidgets('opens a card with Remove from favorites and a trash icon', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(dots().first);
      await tester.pumpAndSettle();

      expect(find.text('Remove from favorites'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('the card hangs just under the first ⋮', (tester) async {
      await _pump(tester);
      final button = tester.getRect(
        find
            .ancestor(of: dots().first, matching: find.byType(IconButton))
            .first,
      );

      await tester.tap(dots().first);
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find
            .ancestor(
              of: find.text('Remove from favorites'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      // 5px under the icon (centred in the button) and 9px in from its right
      // edge (the icon is inset 12), and the design's 44px tall (12 + 20 + 12).
      expect(card.top, closeTo(button.center.dy + 12 + 5, .5));
      expect(card.right, closeTo(button.right - 12 - 9, .5));
      expect(card.height, 44);
    });

    testWidgets('tapping outside closes it and removes nothing', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(dots().first);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(40, 700));
      await tester.pumpAndSettle();

      expect(find.text('Remove from favorites'), findsNothing);
      expect(find.text('Khmer Times'), findsOneWidget);
    });

    testWidgets('removes the favorite and says so', (tester) async {
      await _pump(tester);

      await tester.tap(dots().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from favorites'));
      await tester.pumpAndSettle();

      expect(find.text('Khmer Times'), findsNothing);
      expect(find.text('Morning FM'), findsOneWidget);
      expect(find.text('Removed from Favorites'), findsOneWidget);
      expect(_saved(), isNot(contains('station:1')));
      expect(_saved(), contains('station:3'));
    });

    testWidgets('removing a song does not re-ask the catalog', (tester) async {
      await _pump(tester);

      await _pick(tester, 'Song');
      await tester.tap(dots().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from favorites'));
      await tester.pumpAndSettle();

      expect(find.text('In Between Us'), findsNothing);
      expect(find.text('Waves of Serenity'), findsOneWidget);
      expect(_saved(), isNot(contains('media:11')));
      expect(lookups, hasLength(1));
    });

    testWidgets('a favorite added elsewhere is looked up when it shows', (
      tester,
    ) async {
      await _pump(tester);
      await _pick(tester, 'Song');
      expect(find.text('Not Saved'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FavoritesView)),
      );
      container.read(favoritesProvider.notifier).toggle('media:14');
      await tester.pumpAndSettle();

      expect(find.text('Not Saved'), findsOneWidget);
      expect(lookups, ['11,12,13', '11,12,13,14']);
    });
  });
}
