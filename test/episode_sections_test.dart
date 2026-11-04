import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/models/program.dart';
import 'package:e_radio/data/models/user_profile.dart';
import 'package:e_radio/data/repositories/media_content_repository.dart';
import 'package:e_radio/data/repositories/program_repository.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/providers/favorites_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/screens/player/now_playing_view.dart';
import 'package:e_radio/views/widgets/player/episode_sections.dart';

import 'support/test_fonts.dart';

/// A player that says what is playing and notes what it is told to play next.
class _FakePlayer extends AudioPlayerController {
  _FakePlayer(this.initial);

  final PlaybackState initial;
  final played = <({String id, List<String> queue, int? index})>[];

  @override
  PlaybackState build() => initial;

  @override
  Future<void> play(
    NowPlayingItem item, {
    List<NowPlayingItem>? queue,
    int? queueIndex,
  }) async {
    played.add((
      id: item.id,
      queue: [for (final q in queue ?? const <NowPlayingItem>[]) q.id],
      index: queueIndex,
    ));
  }

  @override
  Stream<Duration> get positionStream =>
      Stream.value(const Duration(minutes: 12, seconds: 32));

  @override
  Stream<Duration?> get durationStream =>
      Stream.value(const Duration(minutes: 38));
}

class _SignedIn extends AuthController {
  @override
  UserProfile? build() => UserProfile(
    id: '1',
    firstName: 'Pov',
    lastName: 'Chhin',
    email: 'pov@example.com',
    joinedAt: DateTime(2026),
  );
}

/// Podcast episode [n]. Only the first has a run time, an age and a
/// description, as the one playing is the one that shows them.
MediaContent _content(
  int n, {
  String? description,
  bool streams = true,
  String slug = 'podcast',
}) => MediaContent(
  id: '$n',
  title: 'Show talk $n',
  mediaType: 'audio',
  streamUrl: streams ? 'https://example.com/$n.mp3' : null,
  categorySlug: slug,
  categoryName: switch (slug) {
    'podcast' => 'Podcast',
    'news' => 'News',
    'health' => 'Health',
    'economyfinance' => 'Economy/Finance',
    _ => slug,
  },
  artistName: 'Host $n',
  durationSeconds: n == 1 ? 38 * 60 : null,
  publishedAt: n == 1 ? DateTime.now() : null,
  description: n == 1 ? description : null,
);

NowPlayingItem _item(int n, {String slug = 'podcast', String? description}) =>
    NowPlayingItem.fromMediaContent(
      _content(n, slug: slug, description: description),
    )!;

/// A category's first page, as the API lists it: episodes 1 to [count].
List<MediaContent> _listing(String slug, int count) => [
  for (var n = 1; n <= count; n++) _content(n, slug: slug),
];

/// A show with the episodes numbered [from] to [to]; its record says it has
/// [count] (the number of episodes it lists, if not given).
Program _show(int id, int from, int to) => Program(
  id: '$id',
  name: 'Show $id',
  episodeCount: to - from + 1,
  episodes: [for (var n = from; n <= to; n++) _content(n)],
);

PlaybackState _playing(NowPlayingItem item, {List<NowPlayingItem>? queue}) =>
    PlaybackState(
      item: item,
      status: PlaybackStatus.playing,
      queue: queue ?? const [],
    );

/// The overrides that stand in for the API's shows: the list of them without
/// their episodes, as the list endpoint has it, and each one in full — and its
/// categories, by slug, each as its first page.
List<Override> _api(
  List<Program> shows, {
  Map<String, List<MediaContent>> categories = const {},
  List<String>? asked,
  Future<List<Program>> Function()? list,
  Future<Program> Function(String id)? detail,
}) => [
  mediaContentsByCategoryProvider.overrideWith((ref, slug) {
    asked?.add('category:$slug');
    return Future.value(categories[slug] ?? const <MediaContent>[]);
  }),
  programsProvider.overrideWith((ref) {
    asked?.add('shows');
    if (list != null) return list();
    return Future.value([
      for (final show in shows)
        Program(id: show.id, name: show.name, episodeCount: show.episodeCount),
    ]);
  }),
  programProvider.overrideWith((ref, id) {
    asked?.add('show:$id');
    if (detail != null) return detail(id);
    return Future.value(shows.firstWhere((show) => show.id == id));
  }),
];

Future<_FakePlayer> _pump(
  WidgetTester tester,
  PlaybackState playback, {
  List<Override> api = const [],
  Size size = const Size(390, 844),
  bool signedIn = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final player = _FakePlayer(playback);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        audioPlayerControllerProvider.overrideWith(() => player),
        ...api,
        if (signedIn) authControllerProvider.overrideWith(_SignedIn.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NowPlayingView(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return player;
}

/// Episode 1, in a show of [count] episodes.
Future<_FakePlayer> _pumpShow(
  WidgetTester tester,
  int count, {
  String? description,
  Size size = const Size(390, 844),
  bool signedIn = false,
}) => _pump(
  tester,
  _playing(_item(1, description: description)),
  api: _api([_show(6, 1, count)]),
  size: size,
  signedIn: signedIn,
);

Finder get _card => find.byKey(const Key('episodeCard'));
Finder get _pill => find.byKey(const Key('episodesPill'));
Finder get _seeMore => find.byKey(const Key('episodeSeeMore'));
Finder get _sheetList => find.byKey(const Key('episodesSheetList'));

Finder _in(Finder scope, String text) =>
    find.descendant(of: scope, matching: find.text(text));

void main() {
  setUpAll(loadTestFonts);

  group('hasEpisodeSections', () {
    test('is for a podcast, news, health, economy/finance or song', () {
      for (final slug in [
        'podcast',
        'news',
        'health',
        'economyfinance',
        'song',
      ]) {
        expect(hasEpisodeSections(_item(1, slug: slug)), isTrue, reason: slug);
      }
    });

    test('has the list of others for a podcast episode only', () {
      expect(hasEpisodeList(_item(1, slug: 'podcast')), isTrue);
      // The others have the card about them, and no list.
      for (final slug in ['news', 'health', 'economyfinance', 'song']) {
        expect(hasEpisodeSections(_item(1, slug: slug)), isTrue, reason: slug);
        expect(hasEpisodeList(_item(1, slug: slug)), isFalse, reason: slug);
      }
      expect(hasEpisodeList(_item(1, slug: 'ambient-music')), isFalse);
    });

    test('is not for ambient music, a station or nothing', () {
      for (final slug in ['ambient-music']) {
        expect(hasEpisodeSections(_item(1, slug: slug)), isFalse, reason: slug);
      }
      expect(
        hasEpisodeSections(
          const NowPlayingItem(
            id: 'media:1',
            title: 'No category',
            streamUrl: 'https://example.com/1.mp3',
            isLive: false,
          ),
        ),
        isFalse,
      );
      expect(
        hasEpisodeSections(
          const NowPlayingItem(
            id: 'station:1',
            title: 'Apsara FM',
            streamUrl: 'https://example.com/live.m3u8',
            isLive: true,
            categorySlug: 'podcast',
          ),
        ),
        isFalse,
      );
    });
  });

  group('the show of an episode', () {
    /// Opens a container, and lets what [watched] asks of the API come back.
    Future<ProviderContainer> open(
      List<Override> api,
      List<ProviderListenable<Object?>> watched,
    ) async {
      final container = ProviderContainer(overrides: api);
      addTearDown(container.dispose);
      for (final provider in watched) {
        container.listen(provider, (_, _) {});
      }
      await pumpEventQueue();
      return container;
    }

    final shows = [_show(5, 1, 2), _show(6, 3, 4)];

    test('is the one that lists it', () async {
      final container = await open(_api(shows), [
        programOfEpisodeProvider('3'),
      ]);

      expect(container.read(programOfEpisodeProvider('3'))?.id, '6');
    });

    test('is none for an episode no show lists', () async {
      final container = await open(_api(shows), [
        programOfEpisodeProvider('99'),
      ]);

      expect(container.read(programOfEpisodeProvider('99')), isNull);
    });

    test('asks for the list of shows and each show at once', () async {
      final asked = <String>[];
      await open(_api(shows, asked: asked), [programOfEpisodeProvider('3')]);

      expect(asked, unorderedEquals(['shows', 'show:5', 'show:6']));
    });

    test('is found even if another show fails to load', () async {
      final container = await open(
        _api(
          shows,
          detail: (id) => id == '5'
              ? Future.error(Exception('offline'))
              : Future.value(shows.firstWhere((show) => show.id == id)),
        ),
        [programOfEpisodeProvider('4')],
      );

      expect(container.read(programOfEpisodeProvider('4'))?.id, '6');
    });

    test('is none, for now, while the shows load', () async {
      final never = Completer<List<Program>>();
      final container = await open(_api(shows, list: () => never.future), [
        programOfEpisodeProvider('3'),
      ]);

      expect(container.read(programOfEpisodeProvider('3')), isNull);
    });

    test('is none if the list of shows cannot be loaded', () async {
      // (Riverpod keeps retrying a failed load: let it fail, and look.)
      final container = await open(
        _api(shows, list: () => Future.error(Exception('offline'))),
        [programOfEpisodeProvider('3')],
      );

      expect(container.read(programOfEpisodeProvider('3')), isNull);
    });

    test('has the episodes that can play, newest first', () async {
      final show = Program(
        id: '6',
        name: 'Show 6',
        episodes: [_content(1), _content(2, streams: false), _content(3)],
      );
      final container = await open(_api([show]), [showEpisodesProvider('1')]);

      final episodes = container.read(showEpisodesProvider('1'));

      expect(episodes.map((e) => e.id), ['media:1', 'media:3']);
    });

    test('has none for an episode in no show', () async {
      final container = await open(_api([_show(6, 1, 4)]), [
        showEpisodesProvider('99'),
      ]);

      expect(container.read(showEpisodesProvider('99')), isEmpty);
    });

    test('the others are its episodes but the one playing', () async {
      final container = await open(_api([_show(6, 1, 4)]), [
        otherEpisodesProvider('2'),
      ]);

      expect(container.read(otherEpisodesProvider('2')).map((e) => e.id), [
        'media:1',
        'media:3',
        'media:4',
      ]);
    });

    test('the others are none while it is found, or if it cannot be', () async {
      final never = Completer<List<Program>>();
      final loading = await open(_api(shows, list: () => never.future), [
        otherEpisodesProvider('3'),
      ]);
      expect(loading.read(otherEpisodesProvider('3')), isEmpty);

      final failing = await open(
        _api(shows, list: () => Future.error(Exception('offline'))),
        [otherEpisodesProvider('3')],
      );
      expect(failing.read(otherEpisodesProvider('3')), isEmpty);
    });
  });

  group('About the episode', () {
    testWidgets('lies right under the controls, in view on a normal phone', (
      tester,
    ) async {
      await _pumpShow(tester, 3);

      final controls = tester.getCenter(find.byIcon(Icons.pause_rounded)).dy;
      final about = tester
          .getTopLeft(find.byKey(const Key('aboutEpisodeCard')))
          .dy;
      expect(about, greaterThan(controls));
      // Close under them, not a screen further down.
      expect(about - controls, lessThan(150));
      expect(about, lessThan(844));
    });

    testWidgets('on a short phone the controls stay in view and it is below', (
      tester,
    ) async {
      await _pumpShow(tester, 3, size: const Size(390, 640));

      // The picture gave way, as it always has, so the controls fit…
      final controls = tester.getCenter(find.byIcon(Icons.pause_rounded)).dy;
      expect(controls, lessThan(640));
      // …and the rest is a scroll away, under the first screen.
      expect(
        tester.getTopLeft(find.byKey(const Key('aboutEpisodeCard'))).dy,
        greaterThanOrEqualTo(640),
      );
    });

    testWidgets('a podcast has the heading, with the Episodes button level', (
      tester,
    ) async {
      await _pumpShow(tester, 3);

      final heading = find.text('Details');
      expect(heading, findsOneWidget);
      expect(find.byKey(const Key('aboutEpisodeCard')), findsOneWidget);
      // The heading is at the left, the button at the right, on one line…
      expect(tester.getTopLeft(heading).dx, 20);
      expect(tester.getTopRight(_pill).dx, 390 - 20);
      expect(
        (tester.getCenter(heading).dy - tester.getCenter(_pill).dy).abs(),
        lessThan(12),
      );
      // …both above the card.
      expect(
        tester.getBottomLeft(heading).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('aboutEpisodeCard'))).dy,
        ),
      );
    });

    testWidgets('a podcast alone in its show still has the heading', (
      tester,
    ) async {
      await _pumpShow(tester, 1);

      expect(find.text('Details'), findsOneWidget);
      expect(_pill, findsNothing);
    });

    testWidgets('news, health, economy/finance and songs have no heading and '
        'no Episodes button, just the card', (tester) async {
      for (final slug in ['news', 'health', 'economyfinance', 'song']) {
        await _pump(
          tester,
          _playing(_item(1, slug: slug)),
          api: _api([_show(6, 1, 4)], categories: {slug: _listing(slug, 4)}),
        );

        expect(find.text('Details'), findsNothing, reason: slug);
        expect(find.byKey(const Key('aboutEpisodeCard')), findsOneWidget);
        expect(_pill, findsNothing, reason: slug);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('has the title, how long and how old, and what it is about', (
      tester,
    ) async {
      await _pumpShow(tester, 3, description: 'Ten habits for wealth.');

      final card = find.byKey(const Key('aboutEpisodeCard'));
      expect(_in(card, 'Show talk 1'), findsOneWidget);
      expect(_in(card, '38 mins • Today'), findsOneWidget);
      expect(_in(card, 'Ten habits for wealth.'), findsOneWidget);
      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is only as long as what is known of the episode', (
      tester,
    ) async {
      await _pumpShow(tester, 1);

      final card = find.byKey(const Key('aboutEpisodeCard'));
      expect(_in(card, 'Show talk 1'), findsOneWidget);
      // No description, so no gap or empty line for one: a title, a run time.
      expect(
        find.descendant(of: card, matching: find.byType(Text)),
        findsNWidgets(2),
      );
    });

    testWidgets('ambient music and a station do not have it', (tester) async {
      for (final slug in ['ambient-music']) {
        final asked = <String>[];
        await _pump(
          tester,
          _playing(_item(1, slug: slug)),
          api: _api(
            [_show(6, 1, 4)],
            categories: {slug: _listing(slug, 4)},
            asked: asked,
          ),
        );

        expect(
          find.byKey(const Key('aboutEpisodeCard')),
          findsNothing,
          reason: slug,
        );
        expect(_card, findsNothing, reason: slug);
        // And nothing is asked of the API for them.
        expect(asked, isEmpty, reason: slug);
        await tester.pumpWidget(const SizedBox());
      }

      await _pump(
        tester,
        const PlaybackState(
          item: NowPlayingItem(
            id: 'station:1',
            title: 'Apsara FM',
            streamUrl: 'https://example.com/live.m3u8',
            isLive: true,
          ),
          status: PlaybackStatus.playing,
        ),
      );
      expect(find.byKey(const Key('aboutEpisodeCard')), findsNothing);
    });
  });

  group('news, health, economy/finance and songs', () {
    for (final slug in ['news', 'health', 'economyfinance', 'song']) {
      testWidgets('$slug has the card about it, and nothing else', (
        tester,
      ) async {
        final asked = <String>[];
        await _pump(
          tester,
          _playing(_item(1, slug: slug, description: 'About this one.')),
          // Even with others in its category, and a show full of episodes.
          api: _api(
            [_show(6, 1, 9)],
            categories: {slug: _listing(slug, 6)},
            asked: asked,
          ),
        );

        final card = find.byKey(const Key('aboutEpisodeCard'));
        expect(card, findsOneWidget, reason: slug);
        expect(_in(card, 'Show talk 1'), findsOneWidget, reason: slug);
        expect(_in(card, 'About this one.'), findsOneWidget, reason: slug);
        // No heading, no Episodes button, no list of others, no popup, no badge.
        expect(find.text('Details'), findsNothing, reason: slug);
        expect(_pill, findsNothing, reason: slug);
        expect(_card, findsNothing, reason: slug);
        expect(_seeMore, findsNothing, reason: slug);
        expect(find.text('Episode'), findsNothing, reason: slug);
        expect(find.text('Episodes'), findsNothing, reason: slug);
        // And nothing is asked of the API for them.
        expect(asked, isEmpty, reason: slug);
      });
    }

    testWidgets('keep the card on a short phone, below the controls', (
      tester,
    ) async {
      await _pump(
        tester,
        _playing(_item(1, slug: 'news')),
        api: _api(const []),
        size: const Size(390, 640),
      );

      final controls = tester.getCenter(find.byIcon(Icons.pause_rounded)).dy;
      expect(controls, lessThan(640));
      expect(
        tester.getTopLeft(find.byKey(const Key('aboutEpisodeCard'))).dy,
        greaterThan(controls),
      );
    });

    testWidgets('the heart on the card favorites the item', (tester) async {
      await _pump(
        tester,
        _playing(_item(1, slug: 'song')),
        api: _api(const []),
        signedIn: true,
      );
      final favorites = ProviderScope.containerOf(
        tester.element(find.byType(NowPlayingView)),
      );
      final card = find.byKey(const Key('aboutEpisodeCard'));

      await tester.ensureVisible(card);
      await tester.tap(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
      );
      await tester.pump();

      expect(favorites.read(favoritesProvider), {'media:1'});
    });

    testWidgets('a podcast asks only for its show, never for the category', (
      tester,
    ) async {
      final asked = <String>[];
      await _pump(
        tester,
        _playing(_item(1)),
        api: _api(
          [_show(6, 1, 3)],
          categories: {'podcast': _listing('podcast', 9)},
          asked: asked,
        ),
      );

      expect(asked.where((a) => a.startsWith('category:')), isEmpty);
      // Its show's two others, not the category's eight.
      expect(_in(_card, 'Show talk 2'), findsOneWidget);
      expect(_in(_card, 'Show talk 3'), findsOneWidget);
      expect(find.textContaining('Show talk 4'), findsNothing);
    });
  });

  group('the Episode card', () {
    testWidgets('asks the API for the shows, and each in full', (tester) async {
      final asked = <String>[];
      await _pump(
        tester,
        _playing(_item(1)),
        api: _api([_show(6, 1, 3), _show(7, 4, 5)], asked: asked),
      );

      expect(asked, containsAll(['shows', 'show:6', 'show:7']));
    });

    testWidgets('lists the show\'s other episodes, not the one playing', (
      tester,
    ) async {
      await _pumpShow(tester, 4);

      expect(_card, findsOneWidget);
      expect(_in(_card, 'Episode'), findsOneWidget); // its heading
      expect(_in(_card, 'Show talk 2'), findsOneWidget);
      expect(_in(_card, 'Show talk 3'), findsOneWidget);
      expect(_in(_card, 'Show talk 4'), findsOneWidget);
      expect(_in(_card, 'Show talk 1'), findsNothing);
      // Each under what it is filed under.
      expect(_in(_card, 'Podcast · Host 2'), findsOneWidget);
    });

    testWidgets('comes from its own show: not the play list, not other shows', (
      tester,
    ) async {
      // Started from a list of other things altogether.
      final unrelated = [
        for (var n = 70; n < 73; n++)
          NowPlayingItem(
            id: 'media:$n',
            title: 'Only in the play list $n',
            streamUrl: 'https://example.com/$n.mp3',
            isLive: false,
            categorySlug: 'song',
          ),
      ];
      await _pump(
        tester,
        _playing(_item(1), queue: [_item(1), ...unrelated]),
        // Episodes 4 and 5 are in a show of their own.
        api: _api([_show(6, 1, 3), _show(7, 4, 5)]),
      );

      expect(_in(_card, 'Show talk 2'), findsOneWidget);
      expect(_in(_card, 'Show talk 3'), findsOneWidget);
      expect(find.textContaining('Show talk 4'), findsNothing);
      expect(find.textContaining('Show talk 5'), findsNothing);
      expect(find.textContaining('Only in the play list'), findsNothing);
    });

    testWidgets('shows four, with see more for the rest', (tester) async {
      await _pumpShow(tester, 8);

      for (var n = 2; n <= 5; n++) {
        expect(_in(_card, 'Show talk $n'), findsOneWidget);
      }
      expect(_in(_card, 'Show talk 6'), findsNothing);
      expect(_seeMore, findsOneWidget);
    });

    testWidgets('has see more even when all of them are shown', (tester) async {
      await _pumpShow(tester, 5); // four others, all in the card

      expect(_in(_card, 'Show talk 5'), findsOneWidget);
      expect(_seeMore, findsOneWidget);
      // At the top right, level with the heading.
      expect(tester.getTopRight(_seeMore).dx, greaterThan(300));
      expect(
        (tester.getCenter(_seeMore).dy -
                tester.getCenter(_in(_card, 'Episode')).dy)
            .abs(),
        lessThan(12),
      );
    });

    testWidgets('has see more with a single other episode, as in the design', (
      tester,
    ) async {
      await _pumpShow(tester, 2); // one other

      expect(_in(_card, 'Show talk 2'), findsOneWidget);
      expect(_seeMore, findsOneWidget);

      await tester.ensureVisible(_seeMore);
      await tester.tap(_seeMore);
      await tester.pumpAndSettle();

      expect(_in(_sheetList, 'Show talk 2'), findsOneWidget);
    });

    testWidgets('is not there when the episode is alone in its show', (
      tester,
    ) async {
      await _pumpShow(tester, 1);

      expect(_card, findsNothing);
      expect(_pill, findsNothing);
      expect(find.byKey(const Key('aboutEpisodeCard')), findsOneWidget);
    });

    testWidgets('is not there for an episode that is in no show', (
      tester,
    ) async {
      await _pump(
        tester,
        _playing(_item(99)),
        api: _api([_show(6, 1, 4)]), // none of them lists 99
      );

      expect(_card, findsNothing);
      expect(_pill, findsNothing);
      expect(find.byKey(const Key('aboutEpisodeCard')), findsOneWidget);
    });

    testWidgets('is not there while the shows load, nor if they fail', (
      tester,
    ) async {
      final never = Completer<List<Program>>();
      await _pump(
        tester,
        _playing(_item(1)),
        api: _api([_show(6, 1, 4)], list: () => never.future),
      );
      expect(_card, findsNothing);
      expect(_pill, findsNothing);
      expect(find.byKey(const Key('aboutEpisodeCard')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        _playing(_item(1)),
        api: _api([
          _show(6, 1, 4),
        ], list: () => Future.error(Exception('offline'))),
      );
      expect(_card, findsNothing);
      expect(find.byKey(const Key('aboutEpisodeCard')), findsOneWidget);
    });

    testWidgets('tapping an episode plays it, with its show as the list', (
      tester,
    ) async {
      final player = await _pumpShow(tester, 4);

      await tester.ensureVisible(_in(_card, 'Show talk 3'));
      await tester.tap(_in(_card, 'Show talk 3'));
      await tester.pump();

      expect(player.played, hasLength(1));
      expect(player.played.single.id, 'media:3');
      expect(player.played.single.queue, [
        'media:1',
        'media:2',
        'media:3',
        'media:4',
      ]);
      expect(player.played.single.index, 2);
    });

    testWidgets('the one playing leads the list if the show cannot play it', (
      tester,
    ) async {
      // The show lists episode 1, but without anything to play.
      final show = Program(
        id: '6',
        name: 'Show 6',
        episodeCount: 3,
        episodes: [_content(1, streams: false), _content(2), _content(3)],
      );
      final player = await _pump(tester, _playing(_item(1)), api: _api([show]));

      await tester.ensureVisible(_in(_card, 'Show talk 3'));
      await tester.tap(_in(_card, 'Show talk 3'));
      await tester.pump();

      expect(player.played.single.queue, ['media:1', 'media:2', 'media:3']);
      expect(player.played.single.index, 2);
    });

    testWidgets('its ⋮ adds that episode to the favorites, and takes it out', (
      tester,
    ) async {
      await _pumpShow(tester, 4, signedIn: true);
      final favorites = ProviderScope.containerOf(
        tester.element(find.byType(NowPlayingView)),
      );
      final firstMenu = find
          .descendant(of: _card, matching: find.byIcon(Icons.more_vert_rounded))
          .first;

      await tester.ensureVisible(firstMenu);
      await tester.tap(firstMenu);
      await tester.pumpAndSettle();
      // Favorites, as in every other ⋮ — not bookmarks.
      expect(find.text('Add to bookmarks'), findsNothing);
      await tester.tap(find.text('Add to favorites'));
      await tester.pumpAndSettle();

      expect(favorites.read(favoritesProvider), {'media:2'});

      await tester.tap(firstMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from favorites'));
      await tester.pumpAndSettle();

      expect(favorites.read(favoritesProvider), isEmpty);
    });

    testWidgets('the ⋮ Play steps through the show too', (tester) async {
      final player = await _pumpShow(tester, 4);
      final firstMenu = find
          .descendant(of: _card, matching: find.byIcon(Icons.more_vert_rounded))
          .first;

      await tester.ensureVisible(firstMenu);
      await tester.tap(firstMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();

      expect(player.played.single.id, 'media:2');
      expect(player.played.single.queue, [
        'media:1',
        'media:2',
        'media:3',
        'media:4',
      ]);
      expect(player.played.single.index, 1);
    });

    testWidgets('each has its own ⋮', (tester) async {
      await _pumpShow(tester, 4);

      expect(
        find.descendant(
          of: _card,
          matching: find.byIcon(Icons.more_vert_rounded),
        ),
        findsNWidgets(3),
      );
    });
  });

  group('the Episodes popup', () {
    testWidgets('opens from the Episodes button, with every other one', (
      tester,
    ) async {
      await _pumpShow(tester, 8);

      await tester.ensureVisible(_pill);
      await tester.tap(_pill);
      await tester.pumpAndSettle();

      expect(_sheetList, findsOneWidget);
      for (var n = 2; n <= 8; n++) {
        expect(_in(_sheetList, 'Show talk $n'), findsOneWidget);
      }
      expect(_in(_sheetList, 'Show talk 1'), findsNothing);
    });

    testWidgets('opens from see more too', (tester) async {
      await _pumpShow(tester, 8);

      await tester.ensureVisible(_seeMore);
      await tester.tap(_seeMore);
      await tester.pumpAndSettle();

      expect(_in(_sheetList, 'Show talk 8'), findsOneWidget);
    });

    testWidgets('choosing one closes it and plays that one', (tester) async {
      final player = await _pumpShow(tester, 8);
      await tester.ensureVisible(_pill);
      await tester.tap(_pill);
      await tester.pumpAndSettle();

      await tester.tap(_in(_sheetList, 'Show talk 7'));
      await tester.pumpAndSettle();

      expect(_sheetList, findsNothing);
      expect(player.played.single.id, 'media:7');
      expect(player.played.single.index, 6);
      expect(player.played.single.queue, hasLength(8));
    });

    testWidgets('has the Episode heading over the list', (tester) async {
      await _pumpShow(tester, 8);
      await tester.ensureVisible(_pill);
      await tester.tap(_pill);
      await tester.pumpAndSettle();

      // The card under it has one too; the popup's is the second.
      expect(find.text('Episode'), findsNWidgets(2));
    });
  });

  group('the picture\'s foot', () {
    testWidgets('has no EP badge over the title, however many episodes', (
      tester,
    ) async {
      await _pumpShow(tester, 6);

      // No "6 EP" (or any "N EP") anywhere on the screen…
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && RegExp(r'\d+\s*EP').hasMatch(w.data ?? ''),
        ),
        findsNothing,
      );
      // …so the title is the first thing at the picture's foot.
      final artwork = find.byKey(const Key('nowPlayingArtwork'));
      expect(_in(artwork, 'Show talk 1'), findsOneWidget);
      expect(
        tester.getBottomLeft(artwork).dy -
            tester.getTopLeft(_in(artwork, 'Show talk 1')).dy,
        lessThan(90),
      );
    });

    testWidgets('keeps the LIVE badge for a station', (tester) async {
      await _pump(
        tester,
        const PlaybackState(
          item: NowPlayingItem(
            id: 'station:1',
            title: 'Apsara FM',
            streamUrl: 'https://example.com/live.m3u8',
            isLive: true,
          ),
          status: PlaybackStatus.playing,
        ),
      );

      expect(find.text('LIVE'), findsWidgets);
    });
  });
}
