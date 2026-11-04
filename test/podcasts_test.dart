import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/services/api_client.dart';
import 'package:e_radio/data/services/api_exception.dart';
import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/models/program.dart';
import 'package:e_radio/data/models/tag.dart';
import 'package:e_radio/data/repositories/program_repository.dart';
import 'package:e_radio/data/repositories/tag_repository.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/views/screens/podcasts/podcast_show_view.dart';
import 'package:e_radio/views/screens/podcasts/podcasts_view.dart';
import 'package:e_radio/views/widgets/podcasts/episode_row.dart';
import 'package:e_radio/views/widgets/podcasts/podcast_card.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';

import 'support/test_fonts.dart';

const _shows = [
  Program(
    id: '1',
    name: 'Psychology & Growth',
    hostName: 'Dr. Serey Roth',
    categoryName: 'Health & Mind',
  ),
  Program(id: '2', name: 'Morning Drive', categoryName: 'Podcast'),
  Program(id: '3', name: 'Money Talks'),
];
const _healthShows = [
  Program(id: '1', name: 'Psychology & Growth', hostName: 'Dr. Serey Roth'),
];
final _topics = [
  const Tag(
    id: '1',
    name: 'Podcast',
    slug: 'podcast',
    children: [
      Tag(id: '7', name: 'Health', slug: 'health'),
      Tag(id: '8', name: 'Education', slug: 'education'),
    ],
  ),
  const Tag(id: '2', name: 'News', slug: 'news'),
];

MediaContent _episode(
  String id,
  String title, {
  int? seconds,
  DateTime? published,
  String? stream = 'https://example.com/ep.mp3',
}) => MediaContent(
  id: id,
  title: title,
  mediaType: 'audio',
  streamUrl: stream,
  durationSeconds: seconds,
  publishedAt: published,
);

final _show = Program(
  id: '1',
  name: 'Psychology & Growth',
  description:
      'A podcast about mental health, personal development, '
      'and the science of well-being. Hosted by Dr. Serey Roth, each episode '
      'explores practical strategies for a healthier mind.',
  hostName: 'Dr. Serey Roth',
  categoryName: 'Health & Mind',
  episodeCount: 3,
  episodes: [
    _episode(
      '11',
      'Psychology & Growth',
      seconds: 38 * 60,
      published: DateTime.now(),
    ),
    _episode(
      '12',
      'The Secrets of Better Sleep',
      seconds: 45 * 60,
      published: DateTime.now().subtract(const Duration(days: 1)),
    ),
    _episode(
      '13',
      'How to Manage Daily Stress',
      seconds: 38 * 60,
      published: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ],
);

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
  }
}

late _FakePlayer _player;

/// How many times the first page of "All" was asked for.
int _firstPageLoads = 0;

/// Answers the later pages (`/programs?page=2`) from [reply], and remembers
/// what it was asked.
class _PagesApi extends ApiClient {
  _PagesApi(this.reply);

  final Future<dynamic> Function(String path) reply;
  final paths = <String>[];

  @override
  Future<dynamic> get(String path, {String? token}) {
    paths.add(path);
    return reply(path);
  }
}

List<Program> _manyShows(int from, int to) => [
  for (var i = from; i <= to; i++) Program(id: '$i', name: 'Show $i'),
];

Map<String, dynamic> _page(int from, int to) => {
  'data': [
    for (var i = from; i <= to; i++) {'id': '$i', 'name': 'Show $i'},
  ],
};

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  List<Program> shows = _shows,
  Program? show,
  Object? showError,
  ApiClient? api,
}) async {
  _firstPageLoads = 0;
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  _player = _FakePlayer();

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (c, s) => home),
      GoRoute(
        path: '/podcasts/:id',
        builder: (c, s) =>
            Scaffold(body: Text('show ${s.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        tagsProvider.overrideWith((ref) async => _topics),
        if (api != null) apiClientProvider.overrideWithValue(api),
        programsProvider.overrideWith((ref) async {
          _firstPageLoads++;
          return shows;
        }),
        programsByTagProvider.overrideWith(
          (ref, tagId) async => tagId == '7' ? _healthShows : const [],
        ),
        programProvider.overrideWith((ref, id) async {
          if (showError != null) throw showError;
          return show ?? _show;
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

void main() {
  setUpAll(loadTestFonts);

  group('Program.fromJson', () {
    test('the podcast type stands in for the category in the byline', () {
      final typed = Program.fromJson({
        'id': '1',
        'name': 'Healthy Habits',
        'category': {'name': 'Podcast'},
        'type': {'name': 'Health'},
      });
      final untyped = Program.fromJson({
        'id': '2',
        'name': 'Morning Drive',
        'category': {'name': 'Podcast'},
        'type': null,
      });
      final legacy = Program.fromJson({'id': '3', 'name': 'Old Show'});

      expect(typed.categoryName, 'Health');
      expect(untyped.categoryName, 'Podcast');
      expect(legacy.categoryName, isNull);
    });
  });

  group('Podcasts page', () {
    testWidgets('shows the title, the topic pills and every show', (
      tester,
    ) async {
      await _pump(tester, const PodcastsView());

      expect(find.text('Podcasts'), findsOneWidget);
      for (final label in ['All', 'Health', 'Education']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final show in _shows) {
        expect(find.text(show.name), findsOneWidget);
      }
      expect(find.text('by Dr. Serey Roth • Health & Mind'), findsOneWidget);
      expect(find.text('Podcast'), findsOneWidget); // category only
    });

    testWidgets('lays the cards out on the designed grid', (tester) async {
      await _pump(tester, const PodcastsView());

      // 390 wide: 20 gutter, two 169 cells 12 apart, a 158 card centred in each.
      final first = tester.getTopLeft(find.text('Psychology & Growth'));
      final second = tester.getTopLeft(find.text('Morning Drive'));
      expect(first.dx, closeTo(25.5, .01));
      expect(second.dx, closeTo(206.5, .01));
      expect(second.dy, first.dy);

      // The name sits 176 below the top of its card: 164 of stacked covers and
      // a 12 gap. Rows are 12 apart, so the third show starts one row down.
      final cardTop = tester.getTopLeft(find.byType(PodcastCard).first).dy;
      expect(first.dy - cardTop, 176);
      final third = tester.getTopLeft(find.text('Money Talks'));
      expect(third.dx, closeTo(25.5, .01));
      expect(third.dy - first.dy, inInclusiveRange(220 + 12, 244 + 12));
    });

    testWidgets('a pill narrows the grid to that topic, All brings it back', (
      tester,
    ) async {
      await _pump(tester, const PodcastsView());

      await tester.tap(find.text('Health'));
      await tester.pumpAndSettle();
      expect(find.text('Psychology & Growth'), findsOneWidget);
      expect(find.text('Morning Drive'), findsNothing);

      await tester.tap(find.text('Education'));
      await tester.pumpAndSettle();
      expect(find.text('No podcasts yet'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Morning Drive'), findsOneWidget);
    });

    testWidgets('the chosen pill is violet, the others white', (tester) async {
      await _pump(tester, const PodcastsView());

      Color fillOf(String label) => tester
          .widget<Material>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Material))
                .first,
          )
          .color!;

      expect(fillOf('All'), const Color(0xFF8B5CF6));
      expect(fillOf('Health'), Colors.white);

      await tester.tap(find.text('Health'));
      await tester.pumpAndSettle();
      expect(fillOf('Health'), const Color(0xFF8B5CF6));
      expect(fillOf('All'), Colors.white);
    });

    testWidgets('a card opens the show', (tester) async {
      await _pump(tester, const PodcastsView());

      await tester.tap(find.text('Morning Drive'));
      await tester.pumpAndSettle();

      expect(find.text('show 2'), findsOneWidget);
    });

    testWidgets('says so when there are no shows', (tester) async {
      await _pump(tester, const PodcastsView(), shows: const []);

      expect(find.text('No podcasts yet'), findsOneWidget);
    });

    testWidgets('swiping the list sideways moves to the next pill and back', (
      tester,
    ) async {
      await _pump(tester, const PodcastsView());

      Color fillOf(String label) => tester
          .widget<Material>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Material))
                .first,
          )
          .color!;

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(fillOf('Health'), const Color(0xFF8B5CF6));
      expect(fillOf('All'), Colors.white);
      expect(find.text('Psychology & Growth'), findsOneWidget);
      expect(find.text('Morning Drive'), findsNothing);

      await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(fillOf('All'), const Color(0xFF8B5CF6));
      expect(find.text('Morning Drive'), findsOneWidget);
    });

    testWidgets('pulling down reloads the first page', (tester) async {
      await _pump(tester, const PodcastsView());
      expect(_firstPageLoads, 1);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(_firstPageLoads, 2);
      expect(find.text('Morning Drive'), findsOneWidget);
    });
  });

  group('Podcasts paging', () {
    final list = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );

    Future<void> scrollToEnd(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.drag(list, const Offset(0, -1500));
        await tester.pump();
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('a short list has nothing more to ask for', (tester) async {
      final api = _PagesApi((path) async => _page(21, 25));
      await _pump(tester, const PodcastsView(), api: api);
      await scrollToEnd(tester);

      expect(api.paths, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a full page waits until the list is scrolled to its end', (
      tester,
    ) async {
      final api = _PagesApi((path) async => _page(21, 25));
      await _pump(
        tester,
        const PodcastsView(),
        shows: _manyShows(1, 20),
        api: api,
      );

      expect(find.text('Show 1'), findsOneWidget);
      expect(api.paths, isEmpty);
    });

    testWidgets('loads the next 20 at the end, and stops after the last page', (
      tester,
    ) async {
      final api = _PagesApi((path) async => _page(21, 25));
      await _pump(
        tester,
        const PodcastsView(),
        shows: _manyShows(1, 20),
        api: api,
      );

      await scrollToEnd(tester);

      expect(api.paths, ['/programs?page=2']);
      expect(find.text('Show 25'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('keeps asking for pages while they come back full', (
      tester,
    ) async {
      final api = _PagesApi(
        (path) async => path.endsWith('page=2') ? _page(21, 40) : _page(41, 45),
      );
      await _pump(
        tester,
        const PodcastsView(),
        shows: _manyShows(1, 20),
        api: api,
      );

      await scrollToEnd(tester);
      await scrollToEnd(tester);

      expect(api.paths, ['/programs?page=2', '/programs?page=3']);
      expect(find.text('Show 45'), findsOneWidget);
    });

    testWidgets('a topic whose first page is short does not page', (
      tester,
    ) async {
      final api = _PagesApi((path) async => _page(21, 22));
      await _pump(tester, const PodcastsView(), api: api);
      await tester.tap(find.text('Health'));
      await tester.pumpAndSettle();
      await scrollToEnd(tester);

      expect(api.paths, isEmpty);
    });

    testWidgets('a repeated show is not listed twice', (tester) async {
      final api = _PagesApi((path) async => _page(20, 25));
      await _pump(
        tester,
        const PodcastsView(),
        shows: _manyShows(1, 20),
        api: api,
      );

      await scrollToEnd(tester);

      expect(find.text('Show 20'), findsOneWidget);
      expect(find.text('Show 25'), findsOneWidget);
    });

    testWidgets('a failed page offers Retry, which loads it', (tester) async {
      var fail = true;
      final api = _PagesApi((path) async {
        if (fail) throw ApiException('down', statusCode: 500);
        return _page(21, 25);
      });
      await _pump(
        tester,
        const PodcastsView(),
        shows: _manyShows(1, 20),
        api: api,
      );

      await scrollToEnd(tester);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Show 20'), findsOneWidget); // the list is still there
      expect(api.paths, ['/programs?page=2']); // and it did not hammer the API

      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await scrollToEnd(tester);

      expect(find.text('Retry'), findsNothing);
      expect(find.text('Show 25'), findsOneWidget);
    });
  });

  group('Show detail', () {
    testWidgets('shows the name, host and category over the cover', (
      tester,
    ) async {
      await _pump(tester, const PodcastShowView(programId: '1'));

      expect(find.text('Psychology & Growth'), findsNWidgets(2)); // + episode 1
      expect(find.text('by Dr. Serey Roth • Health & Mind'), findsOneWidget);
      expect(find.text('Play Latest'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('All Episodes'), findsOneWidget);
    });

    testWidgets('the cover header is 220 tall', (tester) async {
      await _pump(tester, const PodcastShowView(programId: '1'));

      final header = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 220,
      );
      expect(header, findsOneWidget);
      expect(tester.getSize(header).height, 220);
    });

    testWidgets('lists the episodes numbered, with run time and age', (
      tester,
    ) async {
      await _pump(tester, const PodcastShowView(programId: '1'));

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('The Secrets of Better Sleep'), findsOneWidget);
      expect(find.text('38 mins • Today'), findsOneWidget);
      expect(find.text('45 mins • 1 day ago'), findsOneWidget);
      expect(find.text('38 mins • 2 days ago'), findsOneWidget);
    });

    testWidgets('Play Latest plays the newest episode with all as the queue', (
      tester,
    ) async {
      await _pump(tester, const PodcastShowView(programId: '1'));

      await tester.tap(find.text('Play Latest'));
      await tester.pump();

      expect(_player.played.single.item.id, 'media:11');
      expect(_player.played.single.queue, hasLength(3));
    });

    testWidgets('a row plays that episode', (tester) async {
      await _pump(tester, const PodcastShowView(programId: '1'));

      await tester.tap(find.text('How to Manage Daily Stress'));
      await tester.pump();

      expect(_player.played.single.item.id, 'media:13');
    });

    testWidgets('the ⋮ on a row opens the options popup', (tester) async {
      await _pump(tester, const PodcastShowView(programId: '1'));

      // The header's ⋮ is first; the rows' follow.
      await tester.tap(find.byIcon(Icons.more_vert_rounded).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Add to favorites'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('Follow says it is coming soon', (tester) async {
      await _pump(tester, const PodcastShowView(programId: '1'));

      await tester.tap(find.text('Follow'));
      await tester.pump();

      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('the description is cut short until tapped', (tester) async {
      await _pump(tester, const PodcastShowView(programId: '1'));

      final description = find.textContaining('A podcast about mental health');
      final collapsed = tester.getSize(description).height;
      expect(collapsed, closeTo(60, .5)); // three 20px lines

      await tester.tap(description);
      await tester.pumpAndSettle();
      expect(tester.getSize(description).height, greaterThan(collapsed));
    });

    testWidgets('a show with no episodes says so and cannot Play Latest', (
      tester,
    ) async {
      await _pump(
        tester,
        const PodcastShowView(programId: '1'),
        show: const Program(id: '1', name: 'Quiet Show'),
      );

      expect(find.text('No episodes yet'), findsOneWidget);
      await tester.tap(find.text('Play Latest'));
      await tester.pump();
      expect(_player.played, isEmpty);
    });
  });

  group('a show that is gone', () {
    testWidgets('gets the Content Unavailable page', (tester) async {
      await _pump(
        tester,
        const PodcastShowView(programId: '9'),
        showError: ApiException('Not found', statusCode: 404),
      );

      expect(find.text('Content Unavailable'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('any other failure still just offers Retry', (tester) async {
      await _pump(
        tester,
        const PodcastShowView(programId: '9'),
        showError: ApiException('Server error', statusCode: 500),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Content Unavailable'), findsNothing);
    });
  });

  group('episode meta line', () {
    Future<String?> lineFor(
      WidgetTester tester,
      MediaContent episode, {
      DateTime? now,
    }) async {
      String? line;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              line = episodeMetaLine(context, episode, now: now);
              return const SizedBox();
            },
          ),
        ),
      );
      return line;
    }

    final now = DateTime(2026, 9, 28, 12);

    testWidgets('a week or more back it is the date', (tester) async {
      final line = await lineFor(
        tester,
        _episode('1', 'Old', seconds: 600, published: DateTime(2026, 9, 1)),
        now: now,
      );
      expect(line, startsWith('10 mins • '));
      expect(line, contains('Sep'));
    });

    testWidgets('a single minute is "1 min", never "0 mins"', (tester) async {
      final line = await lineFor(
        tester,
        _episode('1', 'Short', seconds: 20, published: now),
        now: now,
      );
      expect(line, '1 min • Today');
    });

    testWidgets('leaves out what is not known', (tester) async {
      expect(
        await lineFor(tester, _episode('1', 'A', seconds: 300), now: now),
        '5 mins',
      );
      expect(
        await lineFor(tester, _episode('1', 'B', published: now), now: now),
        'Today',
      );
      expect(await lineFor(tester, _episode('1', 'C'), now: now), isNull);
    });
  });
}
