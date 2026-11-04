import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/core/supports/tap_to_play.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/models/artist.dart';
import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/models/tag.dart';
import 'package:e_radio/data/repositories/artist_repository.dart';
import 'package:e_radio/data/repositories/media_content_repository.dart';
import 'package:e_radio/data/repositories/tag_repository.dart';
import 'package:e_radio/views/screens/music/ambient_music_view.dart';
import 'package:e_radio/views/screens/music/music_tags.dart';
import 'package:e_radio/views/screens/music/music_view.dart';
import 'package:e_radio/views/widgets/explore/categories_section.dart';
import 'package:e_radio/views/widgets/music/ambient_hero.dart';
import 'package:e_radio/views/widgets/music/ambient_palette.dart';
import 'package:e_radio/views/widgets/music/artist_avatar.dart';
import 'package:e_radio/views/widgets/music/genres_section.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/shell_background_provider.dart';
import 'package:e_radio/views/themes/app_colors.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';

import 'support/test_fonts.dart';

const _genreNames = ['Hiphop/Rap', 'Rock', 'EDM', 'Country', 'Pop', 'Folk'];

/// The Song and Ambient Music branches, shaped and numbered like the real tag
/// tree: International 20 (genres 22–27) and Local 29 (genres 31–36).
List<Tag> _tree() {
  Tag genres(int genreNode, int firstGenre) => Tag(
    id: '$genreNode',
    name: 'Genre',
    slug: 'genre',
    children: [
      for (var i = 0; i < _genreNames.length; i++)
        Tag(
          id: '${firstGenre + i}',
          name: _genreNames[i],
          slug: _genreNames[i].toLowerCase().replaceAll('/', ''),
        ),
    ],
  );

  return [
    Tag(
      id: '19',
      name: 'Song',
      slug: 'song',
      children: [
        Tag(
          id: '20',
          name: 'International',
          slug: 'international',
          children: [genres(21, 22)],
        ),
        Tag(id: '29', name: 'Local', slug: 'local', children: [genres(30, 31)]),
      ],
    ),
    const Tag(
      id: '38',
      name: 'Ambient Music',
      slug: 'ambient-music',
      // Deliberately not in the design's order.
      children: [
        Tag(
          id: '44',
          name: 'Khmer Traditional Music',
          slug: 'khmer-traditional-music',
        ),
        Tag(id: '43', name: 'Lobby/Lounge', slug: 'lobbylounge'),
        Tag(id: '41', name: 'Yoga', slug: 'yoga'),
        Tag(id: '42', name: 'Working', slug: 'working'),
        Tag(id: '40', name: 'Studying', slug: 'studying'),
        // The only mood with a picture uploaded in the admin.
        Tag(
          id: '39',
          name: 'Reading',
          slug: 'reading',
          imageUrl: 'https://cdn.example.com/reading.webp',
        ),
      ],
    ),
  ];
}

const _allArtists = [
  Artist(id: '1', name: 'Suly Pheng'),
  Artist(id: '2', name: 'Tep Boprek'),
  Artist(id: '3', name: 'G-Devith'),
  Artist(id: '4', name: 'Tep Piseth'),
  Artist(id: '5', name: 'Katuch'),
  Artist(id: '6', name: 'NEO'),
  Artist(id: '7', name: 'Nuth'),
];
const _localArtists = [
  Artist(id: '7', name: 'Nuth'),
  Artist(id: '6', name: 'NEO'),
];

MediaContent _song(String id, String title, String artist) => MediaContent(
  id: id,
  title: title,
  mediaType: 'audio',
  streamUrl: 'https://example.com/$id.mp3',
  artistName: artist,
);

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
final artistRequests = <String>[];
final songRequests = <SongFilter>[];
final tagSongRequests = <String>[];

/// An already-decoded picture as an [ImageProvider].
class _TestImage extends ImageProvider<_TestImage> {
  const _TestImage(this.image);

  final ui.Image image;

  @override
  Future<_TestImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_TestImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        SynchronousFuture(ImageInfo(image: image.clone())),
      );
}

/// What reading a card picture's background gives, for every picture — null
/// being "couldn't read it".
Color? _cardColor;

Future<void> _pump(WidgetTester tester, Widget home, {List<Tag>? tree}) async {
  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  _player = _FakePlayer();
  artistRequests.clear();
  songRequests.clear();
  tagSongRequests.clear();

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (c, s) => home),
      GoRoute(
        path: '/music/ambient',
        builder: (c, s) => const Scaffold(body: Text('ambient page')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tagsProvider.overrideWith((ref) async => tree ?? _tree()),
        popularArtistsProvider.overrideWith((ref, tagIds) async {
          artistRequests.add(tagIds);
          return tagIds == '29' ? _localArtists : _allArtists;
        }),
        popularSongsProvider.overrideWith((ref, filter) async {
          songRequests.add(filter);
          final who = filter.artistId == '7' ? 'Nuth' : 'Suly Pheng';
          return [
            _song('1', 'In Between Us', who),
            _song('2', 'Waves of Serenity', 'Nature Sounds'),
          ];
        }),
        mediaContentsByTagProvider.overrideWith((ref, tagId) async {
          tagSongRequests.add(tagId);
          return [
            _song('10$tagId', 'Song for $tagId', 'Lofi Beats'),
            _song('11$tagId', 'Another for $tagId', 'Meditation Music'),
          ];
        }),
        audioPlayerControllerProvider.overrideWith(() => _player),
        ambientCardColorProvider.overrideWith((ref, url) async => _cardColor),
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

Color _fillOf(WidgetTester tester, String label) => tester
    .widget<Material>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first,
    )
    .color!;

Color _colorOfText(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

const _violet = Color(0xFF8B5CF6);

/// The Ambient Music carousel on its own, as Discover shows it.
const _carousel = Scaffold(
  body: SingleChildScrollView(child: CategoriesSection()),
);

void main() {
  setUpAll(loadTestFonts);
  setUp(() {
    resetTapToPlay();
    _cardColor = null;
  });

  group('MusicTags', () {
    final music = MusicTags.from(_tree());

    test('finds Local and International under Song', () {
      expect(music.local?.id, '29');
      expect(music.international?.id, '20');
      expect(MusicTags.from(const []).local, isNull);
    });

    test('a tab covers its own tag, All covers both', () {
      expect(music.scope('local').map((t) => t.id), ['29']);
      expect(music.scope('international').map((t) => t.id), ['20']);
      expect(music.scope(null).map((t) => t.id), ['29', '20']);
    });

    test('genres come once each, in the order they were created', () {
      expect(music.genreNames(music.scope(null)), _genreNames);
      expect(music.genreNames(music.scope('local')), _genreNames);
    });

    test('a genre name maps to one tag per branch in scope', () {
      expect(music.genreIds(music.scope(null), 'Rock'), ['23', '32']);
      expect(music.genreIds(music.scope('local'), 'Rock'), ['32']);
      expect(music.genreIds(music.scope('international'), 'Rock'), ['23']);
    });
  });

  group('Music page', () {
    testWidgets('shows the title, pills, artists, genres and songs', (
      tester,
    ) async {
      await _pump(tester, const MusicView());

      expect(find.text('Music'), findsOneWidget);
      for (final pill in ['Local', 'International']) {
        expect(find.text(pill), findsOneWidget);
      }
      // "All" starts the tab pills and the genres.
      expect(find.text('All'), findsNWidgets(2));
      expect(find.text('Popular Artists'), findsOneWidget);
      for (final artist in _allArtists) {
        expect(find.text(artist.name), findsOneWidget);
      }
      expect(find.text('Genres'), findsOneWidget);
      for (final genre in _genreNames) {
        expect(find.text(genre), findsOneWidget);
      }
      expect(find.text('Popular Songs'), findsOneWidget);
      expect(find.text('In Between Us'), findsOneWidget);
      expect(find.text('by Suly Pheng'), findsOneWidget);
    });

    testWidgets('has no Ambient Music: no pill and no carousel', (
      tester,
    ) async {
      await _pump(tester, const MusicView());

      expect(find.text('Ambient Music'), findsNothing);
      expect(find.byType(CategoriesSection), findsNothing);
      expect(find.text('READING'), findsNothing);

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      expect(find.text('Ambient Music'), findsNothing);
    });

    // The carousel is Discover's now; it is still drawn from the same tags.
    testWidgets('the carousel has every mood of the Ambient Music tag', (
      tester,
    ) async {
      await _pump(tester, _carousel);

      // Reading and Khmer Traditional Music have no card picture, so they are
      // drawn — and the carousel scrolls on to the last one.
      expect(find.text('READING'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('KHMER TRADITIONAL MUSIC'),
        150,
        scrollable: find.descendant(
          of: find.byType(CategoriesSection),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('KHMER TRADITIONAL MUSIC'), findsOneWidget);
    });

    testWidgets('a mood with an uploaded picture shows it on its card', (
      tester,
    ) async {
      await _pump(tester, _carousel);

      final urls = tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .map((image) => image.imageUrl);
      expect(urls, contains('https://cdn.example.com/reading.webp'));
      // Only Reading has one; the other cards keep the app's own pictures.
      expect(
        urls.where((url) => url.contains('cdn.example.com/reading')),
        hasLength(1),
      );
    });

    test('a tag reads its picture from image_url, and has none without it', () {
      final tags = [
        Tag.fromJson({
          'id': '1',
          'name': 'Working',
          'slug': 'working',
          'image_url': 'https://cdn.example.com/working.webp',
          'children': [
            {'id': '2', 'name': 'Kid', 'slug': 'kid', 'image_url': null},
          ],
        }),
      ];

      expect(tags.single.imageUrl, 'https://cdn.example.com/working.webp');
      expect(tags.single.children.single.imageUrl, isNull);
      final old = Tag.fromJson({'id': '3', 'name': 'Old', 'slug': 'old'});
      expect(old.imageUrl, isNull);
    });

    testWidgets('the tab pills are 32 tall and the genres 38', (tester) async {
      await _pump(tester, const MusicView());

      double heightOf(String label) => tester
          .getSize(
            find
                .ancestor(of: find.text(label), matching: find.byType(Material))
                .first,
          )
          .height;

      expect(heightOf('Local'), 32);
      expect(heightOf('Rock'), 38);
    });

    testWidgets('genres are as wide as their label and wrap in rows', (
      tester,
    ) async {
      await _pump(tester, const MusicView());

      Finder pill(String label) => find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first;

      // Not stretched across the page…
      expect(tester.getSize(pill('Rock')).width, lessThan(120));
      // …so the first few share a line, 12 apart, and the rest wrap below.
      final rap = tester.getTopLeft(pill('Hiphop/Rap'));
      final rock = tester.getTopLeft(pill('Rock'));
      expect(rock.dy, rap.dy);
      expect(rock.dx - tester.getTopRight(pill('Hiphop/Rap')).dx, 12);
      final country = tester.getTopLeft(pill('Country'));
      expect(country.dy, greaterThan(rap.dy));
      // A row break is 8 below the pill above it.
      expect(country.dy - (rap.dy + 38), 8);
    });

    testWidgets('Local narrows the artists and the songs to its tag', (
      tester,
    ) async {
      await _pump(tester, const MusicView());
      expect(artistRequests, ['']);
      expect(songRequests.last.tagIds, '');

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();

      expect(artistRequests.last, '29');
      expect(songRequests.last, (tagIds: '29', artistId: null));
      expect(find.text('G-Devith'), findsNothing);
      expect(find.text('Nuth'), findsOneWidget);
      expect(_fillOf(tester, 'Local'), _violet);
      expect(_fillOf(tester, 'All'), Colors.white);
    });

    testWidgets('a genre covers both branches on All, one on Local', (
      tester,
    ) async {
      await _pump(tester, const MusicView());

      await tester.tap(find.text('Hiphop/Rap'));
      await tester.pumpAndSettle();
      // International (22) and Local (31).
      expect(songRequests.last, (tagIds: '22,31', artistId: null));
      expect(_fillOf(tester, 'Hiphop/Rap'), _violet);

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      expect(songRequests.last, (tagIds: '31', artistId: null));
      // The genre stays chosen across tabs.
      expect(_fillOf(tester, 'Hiphop/Rap'), _violet);
    });

    testWidgets('the genres start with All, and it lets go of the genre', (
      tester,
    ) async {
      await _pump(tester, const MusicView());
      final allGenres = find.descendant(
        of: find.byType(GenresSection),
        matching: find.text('All'),
      );
      Color genreAllFill() => tester
          .widget<Material>(
            find.ancestor(of: allGenres, matching: find.byType(Material)).first,
          )
          .color!;

      // First in the block, and picked while no genre is.
      expect(
        tester.getTopLeft(allGenres).dx,
        lessThan(tester.getTopLeft(find.text('Hiphop/Rap')).dx),
      );
      expect(genreAllFill(), _violet);

      await tester.tap(find.text('Hiphop/Rap'));
      await tester.pumpAndSettle();
      expect(songRequests.last, (tagIds: '22,31', artistId: null));
      expect(genreAllFill(), Colors.white);

      // Back to every genre (the songs are already loaded, so nothing new is
      // asked for).
      await tester.tap(allGenres);
      await tester.pumpAndSettle();
      expect(genreAllFill(), _violet);
      expect(_fillOf(tester, 'Hiphop/Rap'), Colors.white);
    });

    testWidgets('an artist and a genre together narrow the songs', (
      tester,
    ) async {
      await _pump(tester, const MusicView());

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hiphop/Rap'));
      await tester.pumpAndSettle();

      expect(songRequests.last, (tagIds: '31', artistId: '7'));
      expect(find.text('by Nuth'), findsOneWidget);
      // The picked artist's name goes violet and gets a ring.
      expect(_colorOfText(tester, 'Nuth'), _violet);
      expect(_colorOfText(tester, 'NEO'), isNot(_violet));
    });

    testWidgets('tapping the artist again lets go', (tester) async {
      await _pump(tester, const MusicView());

      await tester.tap(find.text('Nuth'));
      await tester.pumpAndSettle();
      expect(songRequests.last.artistId, '7');
      expect(find.text('by Nuth'), findsOneWidget);

      await tester.tap(find.text('Nuth'));
      await tester.pumpAndSettle();
      // Back to everyone's songs (already loaded, so nothing new is asked for).
      expect(find.text('by Suly Pheng'), findsOneWidget);
      expect(find.text('by Nuth'), findsNothing);
      expect(_colorOfText(tester, 'Nuth'), isNot(_violet));
    });

    testWidgets('changing tab clears the picked artist', (tester) async {
      await _pump(tester, const MusicView());

      await tester.tap(find.text('Nuth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('International'));
      await tester.pumpAndSettle();

      expect(songRequests.last, (tagIds: '20', artistId: null));
    });

    testWidgets('artists sit five to a row, 72 round, 12 apart', (
      tester,
    ) async {
      await _pump(tester, const MusicView());

      final avatars = find.byType(ArtistAvatar);
      expect(avatars, findsNWidgets(7));
      expect(tester.getSize(avatars.first), const Size(72, 72));

      final first = tester.getTopLeft(avatars.at(0));
      final second = tester.getTopLeft(avatars.at(1));
      final sixth = tester.getTopLeft(avatars.at(5));
      expect(first.dx, 20);
      expect(second.dx - first.dx, 72 + 12);
      // The sixth starts the second row, under the first.
      expect(sixth.dx, first.dx);
      expect(sixth.dy, greaterThan(first.dy + 72));
      // The fifth runs past the screen edge, so the block scrolls sideways.
      expect(tester.getTopRight(avatars.at(4)).dx, greaterThan(390));
    });

    testWidgets('a song row plays when tapped', (tester) async {
      await _pump(tester, const MusicView());

      await tester.tap(find.text('Waves of Serenity'));
      await tester.pump();

      expect(_player.played.single.id, 'media:2');
    });

    testWidgets('without a genre branch there is no Genres section', (
      tester,
    ) async {
      await _pump(tester, const MusicView(), tree: const []);

      expect(find.text('Genres'), findsNothing);
      expect(find.text('Popular Songs'), findsOneWidget);
    });
  });

  group('Ambient Music page', () {
    testWidgets('opens on the mood that was tapped', (tester) async {
      await _pump(tester, const AmbientMusicView(initialTagSlug: 'studying'));

      expect(_fillOf(tester, 'Studying'), _violet);
      expect(_fillOf(tester, 'Working'), Colors.white);
      expect(find.text('STUDYING'), findsOneWidget);
      expect(tagSongRequests, ['40']);
      expect(find.text('Song for 40'), findsOneWidget);
      expect(find.text('by Lofi Beats'), findsOneWidget);
    });

    testWidgets('gives the shell its color while on screen', (tester) async {
      await _pump(tester, const AmbientMusicView(initialTagSlug: 'studying'));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AmbientMusicView)),
      );
      expect(container.read(shellBackgroundProvider), AppColors.ambientGold);
    });

    testWidgets('hands the shell its color back when its tab is offstage', (
      tester,
    ) async {
      // A tab that is switched away from stays alive, with tickers off.
      await _pump(
        tester,
        const TickerMode(
          enabled: false,
          child: AmbientMusicView(initialTagSlug: 'studying'),
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AmbientMusicView)),
      );
      expect(container.read(shellBackgroundProvider), isNull);
    });

    group('background', () {
      Color pageColor(WidgetTester tester) => Theme.of(
        tester.element(find.byType(Scaffold).first),
      ).scaffoldBackgroundColor;

      Color? titleColor(WidgetTester tester, String title) =>
          tester.widget<Text>(find.text(title)).style!.color;

      testWidgets("follows the background of the mood's card picture", (
        tester,
      ) async {
        _cardColor = const Color(0xFF7B7FF0);
        await _pump(tester, const AmbientMusicView(initialTagSlug: 'reading'));

        expect(pageColor(tester), const Color(0xFF7B7FF0));
        expect(titleColor(tester, 'READING'), Colors.white);
        // The strip around the player takes it too.
        expect(
          ProviderScope.containerOf(
            tester.element(find.byType(AmbientMusicView)),
          ).read(shellBackgroundProvider),
          const Color(0xFF7B7FF0),
        );
      });

      testWidgets('a light card picture gives a light page with dark text', (
        tester,
      ) async {
        _cardColor = const Color(0xFFF3E4D0);
        await _pump(tester, const AmbientMusicView(initialTagSlug: 'reading'));

        expect(pageColor(tester), const Color(0xFFF3E4D0));
        expect(titleColor(tester, 'READING'), AppColors.lightInk);
        final pageTitle = tester.widget<Text>(find.text('Ambient Music'));
        expect(pageTitle.style!.color, AppColors.lightInk);
      });

      testWidgets('a mood without a picture keeps its own colour', (
        tester,
      ) async {
        _cardColor = const Color(0xFF7B7FF0);
        await _pump(tester, const AmbientMusicView(initialTagSlug: 'working'));

        expect(pageColor(tester), AppColors.ambientNavy);
      });

      testWidgets(
        "keeps the mood's own colour when the picture can't be read",
        (tester) async {
          _cardColor = null;
          await _pump(
            tester,
            const AmbientMusicView(initialTagSlug: 'reading'),
          );

          expect(pageColor(tester), AppColors.ambientTeal);
          expect(titleColor(tester, 'READING'), Colors.white);
        },
      );
    });

    group('banner', () {
      Finder inHero(Finder finder) =>
          find.descendant(of: find.byType(AmbientHero), matching: finder);

      testWidgets("is the mood's card picture, the drawn banner standing in "
          'until it arrives', (tester) async {
        await _pump(tester, const AmbientMusicView(initialTagSlug: 'reading'));

        final urls = tester
            .widgetList<CachedNetworkImage>(
              inHero(find.byType(CachedNetworkImage)),
            )
            .map((image) => image.imageUrl);
        expect(urls, ['https://cdn.example.com/reading.webp']);
        // Not arrived (the test has no network): the drawn name and the app's
        // own illustration are there instead.
        expect(inHero(find.text('READING')), findsOneWidget);
        expect(
          inHero(
            find.byWidgetPredicate(
              (w) =>
                  w is Image &&
                  w.image is AssetImage &&
                  (w.image as AssetImage).assetName.contains('reading_hero'),
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('is drawn for a mood without a card picture', (tester) async {
        await _pump(tester, const AmbientMusicView(initialTagSlug: 'working'));

        expect(inHero(find.byType(CachedNetworkImage)), findsNothing);
        expect(inHero(find.text('WORKING')), findsOneWidget);
      });

      testWidgets('is drawn on All, which has no card picture', (tester) async {
        await _pump(tester, const AmbientMusicView());

        expect(inHero(find.byType(CachedNetworkImage)), findsNothing);
        expect(inHero(find.text('AMBIENT MUSIC')), findsOneWidget);
      });

      testWidgets('a loaded picture fills the 210 band, fading at its edges', (
        tester,
      ) async {
        final image = await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
            ),
          );
          return (await codec.getNextFrame()).image;
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AmbientHeroPicture(image: _TestImage(image!))),
          ),
        );

        expect(tester.getSize(find.byType(AmbientHeroPicture)).height, 210);
        expect(find.byType(ShaderMask), findsOneWidget);
      });
    });

    testWidgets('without a mood — See All — it opens on All', (tester) async {
      await _pump(tester, const AmbientMusicView());

      expect(_fillOf(tester, 'All'), _violet);
      expect(_fillOf(tester, 'Working'), Colors.white);
      // The banner carries the page's own name, with no mood's illustration.
      expect(find.text('AMBIENT MUSIC'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName.contains('_hero'),
        ),
        findsNothing,
      );
    });

    testWidgets('All lists every mood\'s songs, asked for under the Ambient '
        'Music tag', (tester) async {
      await _pump(tester, const AmbientMusicView());

      // 38 is the Ambient Music tag — the parent of all the moods.
      expect(tagSongRequests, ['38']);
      expect(find.text('Song for 38'), findsOneWidget);
      expect(find.text('Another for 38'), findsOneWidget);
    });

    testWidgets('All is the first pill, before the moods', (tester) async {
      await _pump(tester, const AmbientMusicView());

      final all = tester.getTopLeft(find.text('All')).dx;
      final working = tester.getTopLeft(find.text('Working')).dx;
      expect(all, lessThan(working));
    });

    testWidgets('a mood card still opens on its own mood, not on All', (
      tester,
    ) async {
      await _pump(tester, const AmbientMusicView(initialTagSlug: 'working'));

      expect(_fillOf(tester, 'Working'), _violet);
      expect(_fillOf(tester, 'All'), Colors.white);
      expect(tagSongRequests, ['42']);
      expect(find.text('Song for 38'), findsNothing);
    });

    testWidgets('a pill goes to a mood and back to All', (tester) async {
      await _pump(tester, const AmbientMusicView());

      await tester.tap(find.text('Working'));
      await tester.pumpAndSettle();
      expect(find.text('Song for 42'), findsOneWidget);
      expect(find.text('WORKING'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(_fillOf(tester, 'All'), _violet);
      expect(find.text('Song for 38'), findsOneWidget);
      expect(find.text('AMBIENT MUSIC'), findsOneWidget);
      expect(find.text('Song for 42'), findsNothing);
    });

    testWidgets('swiping goes from All to the first mood and back', (
      tester,
    ) async {
      await _pump(tester, const AmbientMusicView());

      await tester.fling(
        find.text('AMBIENT MUSIC'),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(_fillOf(tester, 'Working'), _violet);

      await tester.fling(find.text('WORKING'), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(_fillOf(tester, 'All'), _violet);
    });

    testWidgets('a song on All plays, with every song on All queued', (
      tester,
    ) async {
      await _pump(tester, const AmbientMusicView());

      await tester.tap(find.text('Another for 38'));
      await tester.pump();

      expect(_player.played.single.id, 'media:1138');
    });

    testWidgets('lists the moods in the designed order', (tester) async {
      await _pump(tester, const AmbientMusicView());

      final labels = [
        'Working',
        'Reading',
        'Studying',
        'Lobby/Lounge',
        'Yoga',
        'Khmer Traditional Music',
      ];
      final lefts = [
        for (final label in labels) tester.getTopLeft(find.text(label)).dx,
      ];
      expect(lefts, orderedEquals([...lefts]..sort()));
      expect(lefts.toSet(), hasLength(labels.length));
    });

    testWidgets('a pill switches the mood, the banner and the songs', (
      tester,
    ) async {
      await _pump(tester, const AmbientMusicView(initialTagSlug: 'working'));

      // Yoga is past the screen edge until the pills are scrolled.
      await tester.ensureVisible(find.text('Yoga'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();

      expect(_fillOf(tester, 'Yoga'), _violet);
      expect(find.text('YOGA'), findsOneWidget);
      expect(tagSongRequests.last, '41');
      expect(find.text('Song for 41'), findsOneWidget);
      expect(find.text('Song for 42'), findsNothing);
    });

    testWidgets('only Working has an illustration on its banner', (
      tester,
    ) async {
      final illustration = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName.endsWith(
              'ambient_working_hero.png',
            ),
      );

      await _pump(tester, const AmbientMusicView(initialTagSlug: 'working'));
      expect(illustration, findsOneWidget);

      // With All first, Studying is past the screen edge until scrolled to.
      await tester.ensureVisible(find.text('Studying'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Studying'));
      await tester.pumpAndSettle();
      expect(illustration, findsNothing);
    });

    testWidgets('the banner is 210 tall on the deep blue page', (tester) async {
      await _pump(tester, const AmbientMusicView());

      final banner = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 210,
      );
      expect(banner, findsOneWidget);

      final scaffoldContext = tester.element(find.byType(Scaffold));
      expect(
        Theme.of(scaffoldContext).scaffoldBackgroundColor,
        const Color(0xFF1D2A44),
      );
      expect(find.text('Ambient Music'), findsOneWidget); // the title
    });

    testWidgets('a song row plays when tapped', (tester) async {
      await _pump(tester, const AmbientMusicView(initialTagSlug: 'working'));

      await tester.tap(find.text('Another for 42'));
      await tester.pump();

      expect(_player.played.single.id, 'media:1142');
    });
  });
}
