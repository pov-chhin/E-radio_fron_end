import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/apsara_station.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/models/program_slot.dart';
import 'package:e_radio/data/models/station.dart';
import 'package:e_radio/data/repositories/apsara_schedule_repository.dart';
import 'package:e_radio/data/services/api_exception.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/providers/station_provider.dart';
import 'package:e_radio/views/screens/player/now_playing_view.dart';
import 'package:e_radio/views/widgets/shared/full_artwork.dart';
import 'package:e_radio/views/widgets/shared/playing_indicator.dart';

import 'support/test_fonts.dart';

const _fm97Stream = 'https://live.ams.com.kh/radio97/stream/playlist.m3u8';
const _fm99Stream = 'https://live.ams.com.kh/radio99/stream/playlist.m3u8';

const _fm97 = NowPlayingItem(
  id: 'station:10',
  title: 'Apsara FM97',
  streamUrl: _fm97Stream,
  isLive: true,
);

ProgramSlot _slot(
  String name,
  int weekday,
  int from,
  int to, {
  bool replay = false,
}) => ProgramSlot(
  name: name,
  weekday: weekday,
  startMinute: from * 60,
  endMinute: to * 60,
  replay: replay,
);

/// A Monday (2026-11-02) of programs, and a Tuesday's first.
final _week = [
  _slot('Morning Songs', DateTime.monday, 5, 7),
  _slot('Economy Hour', DateTime.monday, 7, 8),
  _slot('Sokdom', DateTime.monday, 14, 15),
  _slot('Cooking Show', DateTime.monday, 15, 16),
  _slot('Dawn Prayer', DateTime.tuesday, 5, 6),
];

DateTime _monday(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 2, hour, minute);

class _FakePlayer extends AudioPlayerController {
  _FakePlayer(this.initial);

  final PlaybackState initial;
  NowPlayingItem? played;
  var toggled = 0;

  @override
  PlaybackState build() => initial;

  @override
  Stream<Duration> get positionStream =>
      Stream.value(const Duration(minutes: 8, seconds: 14));

  @override
  Future<void> play(
    NowPlayingItem item, {
    List<NowPlayingItem>? queue,
    int? queueIndex,
  }) async => played = item;

  @override
  Future<void> togglePlayPause() async => toggled++;
}

class _FakeStations extends StationsNotifier {
  @override
  Future<List<Station>> build() async => const [
    Station(id: '10', name: 'Apsara FM97', streamUrl: _fm97Stream),
    Station(id: '12', name: 'Apsara FM99', streamUrl: _fm99Stream),
    Station(id: '4', name: 'Hang Meas FM 104.5', streamUrl: 'http://x/y.mp3'),
  ];
}

late _FakePlayer _player;

Future<void> _pump(
  WidgetTester tester, {
  NowPlayingItem item = _fm97,
  DateTime? now,
  Future<List<ProgramSlot>> Function()? schedule,
  Size size = const Size(390, 844),
  PlaybackStatus status = PlaybackStatus.playing,
  ThemeData? theme,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  _player = _FakePlayer(PlaybackState(item: item, status: status));
  await tester.pumpWidget(
    ProviderScope(
      retry: (count, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        audioPlayerControllerProvider.overrideWith(() => _player),
        stationsProvider.overrideWith(_FakeStations.new),
        apsaraClockProvider.overrideWithValue(() => now ?? _monday(14, 30)),
        apsaraScheduleProvider.overrideWith(
          (ref, station) => (schedule ?? () async => _week)(),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const NowPlayingView(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(loadTestFonts);

  group('ApsaraStation.fromItem', () {
    NowPlayingItem station(String url, {bool live = true}) => NowPlayingItem(
      id: 'station:1',
      title: 'Apsara FM97',
      streamUrl: url,
      isLive: live,
    );

    test('knows the two stations by their stream', () {
      expect(ApsaraStation.fromItem(station(_fm97Stream)), ApsaraStation.fm97);
      expect(ApsaraStation.fromItem(station(_fm99Stream)), ApsaraStation.fm99);
    });

    test('leaves other streams alone, whatever they are called', () {
      expect(ApsaraStation.fromItem(station('https://x.com/live.m3u8')), isNull);
      expect(
        ApsaraStation.fromItem(
          station('http://studio.devams.site/hls/fm97/live.m3u8'),
        ),
        isNull,
        reason: 'the test channel relays FM97 but has no schedule of its own',
      );
    });

    test('is for live stations only', () {
      expect(ApsaraStation.fromItem(station(_fm97Stream, live: false)), isNull);
    });
  });

  group('ProgramSlot', () {
    test('reads a program of the program site, picture and all', () {
      final slots = ProgramSlot.fromProgramJson({
        'name': 'Health &amp; Beauty',
        'acf': {
          'thumbnail': {
            'url': 'https://x/full.jpg',
            'sizes': {'medium': 'https://x/medium.jpg'},
          },
          'schedules': [
            {
              'day': 'Monday',
              'start_time': '09:00',
              'end_time': '10:30',
              'replay': false,
            },
            {
              'day': 'saturday',
              'start_time': '09:00',
              'end_time': '10:30',
              'replay': true,
            },
          ],
        },
      });

      expect(slots, hasLength(2));
      expect(slots.first.name, 'Health & Beauty');
      expect(slots.first.weekday, DateTime.monday);
      expect(slots.first.imageUrl, 'https://x/medium.jpg');
      expect(slots.first.replay, isFalse);
      expect(slots.last.weekday, DateTime.saturday);
      expect(slots.last.replay, isTrue);
    });

    test('copes with the shapes the site really sends', () {
      // A program without a picture has `thumbnail: false`; one with no
      // schedule has none; and a bad row is skipped, not fatal.
      final slots = ProgramSlot.fromProgramsJson([
        {
          'name': 'A',
          'acf': {
            'thumbnail': false,
            'schedules': [
              {'day': 'Monday', 'start_time': '09:00', 'end_time': '10:00'},
              {'day': 'Someday', 'start_time': '09:00', 'end_time': '10:00'},
              {'day': 'Monday', 'start_time': 'soon', 'end_time': '10:00'},
            ],
          },
        },
        {'name': 'B', 'acf': <String, dynamic>{}},
        {'name': 'C', 'acf': []},
      ]);

      expect(slots, hasLength(1));
      expect(slots.single.imageUrl, isNull);
    });

    test('shows times as the station does', () {
      final slot = _slot('x', DateTime.monday, 14, 15);
      expect(slot.range, '02:00 PM - 03:00 PM');
      expect(slot.startLabel, '2:00 PM');
      expect(_slot('x', 1, 0, 1).range, '12:00 AM - 01:00 AM');
      expect(_slot('x', 1, 11, 12).range, '11:00 AM - 12:00 PM');
    });

    test('a show that ends at "00:00" runs to midnight', () {
      final slot = ProgramSlot.fromProgramJson({
        'name': 'Late',
        'acf': {
          'schedules': [
            {'day': 'Friday', 'start_time': '23:00', 'end_time': '00:00'},
          ],
        },
      }).single;
      expect(slot.endMinute, 1440);
      expect(slot.isOnAt(23 * 60 + 30), isTrue);
      expect(slot.range, '11:00 PM - 12:00 AM');
    });

    test('an end before the start is listed but never on air', () {
      final slot = ProgramSlot.fromProgramJson({
        'name': 'Slip',
        'acf': {
          'schedules': [
            {'day': 'Sunday', 'start_time': '21:00', 'end_time': '20:00'},
          ],
        },
      }).single;
      expect(slot.range, '09:00 PM - 08:00 PM');
      for (final minute in [0, 20 * 60, 21 * 60, 22 * 60, 1439]) {
        expect(slot.isOnAt(minute), isFalse);
      }
    });
  });

  group('DaySchedule', () {
    test('finds what is on and what is next', () {
      final day = DaySchedule.at(_week, _monday(14, 30));
      expect(day.slots.map((s) => s.name), [
        'Morning Songs',
        'Economy Hour',
        'Sokdom',
        'Cooking Show',
      ]);
      expect(day.live?.name, 'Sokdom');
      expect(day.next?.name, 'Cooking Show');
      expect(day.nextIsTomorrow, isFalse);
    });

    test('a program is on from its first minute to just before its last', () {
      expect(DaySchedule.at(_week, _monday(14)).live?.name, 'Sokdom');
      expect(DaySchedule.at(_week, _monday(14, 59)).live?.name, 'Sokdom');
      expect(DaySchedule.at(_week, _monday(15)).live?.name, 'Cooking Show');
    });

    test('between programs nothing is on, and the next is still named', () {
      final day = DaySchedule.at(_week, _monday(10));
      expect(day.live, isNull);
      expect(day.next?.name, 'Sokdom');
    });

    test('after the last program the next is tomorrow\'s first', () {
      final day = DaySchedule.at(_week, _monday(20));
      expect(day.live, isNull);
      expect(day.next?.name, 'Dawn Prayer');
      expect(day.nextIsTomorrow, isTrue);
    });

    test('Sunday night goes on to Monday morning', () {
      final week = [
        _slot('Sunday Late', DateTime.sunday, 20, 21),
        _slot('Monday Early', DateTime.monday, 5, 6),
      ];
      final day = DaySchedule.at(week, DateTime.utc(2026, 11, 1, 22));
      expect(day.next?.name, 'Monday Early');
      expect(day.nextIsTomorrow, isTrue);
    });

    test('an empty week has nothing on', () {
      final day = DaySchedule.at(const [], _monday(12));
      expect(day.slots, isEmpty);
      expect(day.live, isNull);
      expect(day.next, isNull);
    });
  });

  group('the Apsara player', () {
    testWidgets('shows what is on air, what is next and the day\'s programs', (
      tester,
    ) async {
      await _pump(tester);

      // The header, the "on air" cell and the row.
      expect(find.text('Sokdom'), findsNWidgets(3));
      expect(find.text('02:00 PM - 03:00 PM'), findsNWidgets(3));
      // The "next" cell and the row.
      expect(find.text('Cooking Show'), findsNWidgets(2));
      expect(find.text('On Air'), findsOneWidget);
      expect(find.text('Next Program'), findsOneWidget);
      expect(find.text("Today's Programs"), findsOneWidget);
      // Only today's programs, not tomorrow's.
      expect(find.text('Dawn Prayer'), findsNothing);
      // The pill, the live edge of the bar and the row on air.
      expect(find.text('LIVE'), findsNWidgets(3));
      // Earlier programs show their time to start; the one on air says LIVE.
      expect(find.text('5:00 AM'), findsOneWidget);
      expect(find.text('3:00 PM'), findsOneWidget);
      expect(find.text('08:14'), findsOneWidget);
    });

    testWidgets('has the heart, share and the five controls', (tester) async {
      await _pump(tester);

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      final controls = [
        Icons.replay_10_rounded,
        Icons.fast_rewind_rounded,
        Icons.pause_rounded,
        Icons.fast_forward_rounded,
        Icons.forward_10_rounded,
      ];
      final xs = [
        for (final icon in controls) tester.getCenter(find.byIcon(icon)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
      final ys = {
        for (final icon in controls) tester.getCenter(find.byIcon(icon)).dy,
      };
      expect(ys, hasLength(1), reason: 'all on one line');
    });

    testWidgets('play and pause go to the player', (tester) async {
      await _pump(tester);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      expect(_player.toggled, 1);
    });

    testWidgets('next and back go through all the stations, round the ends', (
      tester,
    ) async {
      // The stations, in the list's order: FM97, FM99, Hang Meas.
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.fast_forward_rounded));
      expect(_player.played?.id, 'station:12', reason: 'on to FM99');

      _player.played = null;
      await tester.tap(find.byIcon(Icons.fast_rewind_rounded));
      expect(_player.played?.id, 'station:4', reason: 'back round to the last');
    });

    testWidgets('FM99 goes back to FM97 and on to the next station', (
      tester,
    ) async {
      await _pump(
        tester,
        item: const NowPlayingItem(
          id: 'station:12',
          title: 'Apsara FM99',
          streamUrl: _fm99Stream,
          isLive: true,
        ),
      );

      await tester.tap(find.byIcon(Icons.fast_rewind_rounded));
      expect(_player.played?.streamUrl, _fm97Stream);

      _player.played = null;
      await tester.tap(find.byIcon(Icons.fast_forward_rounded));
      expect(_player.played?.id, 'station:4');
    });

    testWidgets('names the station when no program is on', (tester) async {
      await _pump(tester, now: _monday(3));

      expect(find.text('Apsara FM97'), findsWidgets);
      expect(find.text('វិទ្យុសំឡេងយុវជន ៩៧ · 97.0 MHz'), findsOneWidget);
      // Nothing on: the "on air" cell has no time; the next is the day's first.
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Morning Songs'), findsNWidgets(2));
      expect(find.text('LIVE'), findsNWidgets(2));
    });

    testWidgets('after the last program, next is tomorrow\'s first', (
      tester,
    ) async {
      await _pump(tester, now: _monday(20));

      expect(find.text('Next Program · Tomorrow'), findsOneWidget);
      expect(find.text('Dawn Prayer'), findsOneWidget);
    });

    testWidgets('a replay says so', (tester) async {
      await _pump(
        tester,
        schedule: () async => [
          _slot('Sokdom', DateTime.monday, 14, 15, replay: true),
          _slot('Evening', DateTime.monday, 18, 19, replay: true),
        ],
      );

      // On air, so its header says it is a replay; the one to come has the tag.
      expect(find.text('02:00 PM - 03:00 PM · Replay'), findsOneWidget);
      expect(find.text('Replay'), findsOneWidget);
    });

    testWidgets('says so when there are no programs today', (tester) async {
      await _pump(tester, schedule: () async => const []);

      expect(find.text('No programs scheduled today'), findsOneWidget);
      expect(find.text('Apsara FM97'), findsWidgets);
    });

    testWidgets('offers Retry when the schedule cannot load', (tester) async {
      await _pump(
        tester,
        schedule: () async => throw ApiException('offline'),
      );

      expect(find.text("Couldn't load today's programs"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // The controls are still there: the station plays without a schedule.
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('has the other players\' top bar, and can be minimized', (
      tester,
    ) async {
      await _pump(tester);

      final bar = find.byType(AppBar);
      expect(bar, findsOneWidget);
      expect(
        find.descendant(of: bar, matching: find.text('Apsara FM97')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });

    testWidgets('puts the picture under the top bar, above the controls', (
      tester,
    ) async {
      await _pump(tester);

      final bar = tester.getRect(find.byType(AppBar));
      final heart = tester.getCenter(find.byIcon(Icons.favorite_border_rounded));
      final pause = tester.getCenter(find.byIcon(Icons.pause_rounded));
      // The heart and share are on the picture's foot, under the bar and above
      // the controls.
      expect(heart.dy, greaterThan(bar.bottom));
      expect(heart.dy, lessThan(pause.dy));
      expect(find.text("Today's Programs"), findsOneWidget);
    });

    testWidgets('does not overflow on a short screen, which scrolls', (
      tester,
    ) async {
      await _pump(tester, size: const Size(360, 480));

      expect(tester.takeException(), isNull);
      expect(find.text("Today's Programs"), findsOneWidget);
    });

    testWidgets('scrolls as one page: the programs have no scroll of their own', (
      tester,
    ) async {
      await _pump(tester);

      final vertical = find.byWidgetPredicate(
        (widget) => widget is Scrollable && widget.axis == Axis.vertical,
      );
      expect(vertical, findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(Scrollbar), findsNothing);

      // Dragging anywhere — the picture, or the programs — moves the whole page.
      final before = tester.getTopLeft(find.text("Today's Programs")).dy;
      await tester.drag(find.text("Today's Programs"), const Offset(0, -120));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text("Today's Programs")).dy,
        lessThan(before),
      );
    });

    testWidgets('does not overflow on a small phone', (tester) async {
      await _pump(tester, size: const Size(320, 568));
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a large text size', (tester) async {
      // The rows of programs, and the cells of on air and next, grow with the
      // text rather than spilling out of their boxes.
      for (final scale in [1.15, 1.3, 1.5]) {
        await _pump(tester, textScale: scale);
        expect(tester.takeException(), isNull, reason: 'at $scale×');
      }
    });

    group('with the station\'s own picture', () {
      const withPicture = NowPlayingItem(
        id: 'station:10',
        title: 'Apsara FM97',
        streamUrl: _fm97Stream,
        isLive: true,
        artworkUrl: 'https://example.com/apsara.png',
      );

      testWidgets('shows it, with the bars on it while it plays', (
        tester,
      ) async {
        await _pump(tester, item: withPicture);
        expect(find.byType(FullArtwork), findsOneWidget);
        expect(find.byType(PlayingIndicator), findsOneWidget);
      });

      testWidgets('has no bars on it while paused', (tester) async {
        await _pump(tester, item: withPicture, status: PlaybackStatus.paused);
        expect(find.byType(FullArtwork), findsOneWidget);
        expect(find.byType(PlayingIndicator), findsNothing);
      });

      testWidgets('is the other players\' frame, as wide as the screen', (
        tester,
      ) async {
        await _pump(tester, item: withPicture);
        final frame = tester.getSize(find.byType(FullArtwork));
        expect(frame.width, 390);
        expect(frame.height, 390 / 0.75, reason: 'the 3:4 of the other players');
        // The seek bar and the controls are right under it, on the screen; the
        // programs are further down, to scroll to.
        final pause = tester.getCenter(find.byIcon(Icons.pause_rounded));
        expect(pause.dy, lessThan(844));
      });

      testWidgets('gives way on a short phone so the controls stay on it', (
        tester,
      ) async {
        await _pump(tester, item: withPicture, size: const Size(360, 640));
        final frame = tester.getSize(find.byType(FullArtwork));
        expect(frame.height, lessThan(360 / 0.75));
        expect(frame.height, greaterThanOrEqualTo(180));
        final pause = tester.getCenter(find.byIcon(Icons.pause_rounded));
        expect(pause.dy, lessThan(640));
      });

      testWidgets('leaves the programs under the controls, to scroll to', (
        tester,
      ) async {
        await _pump(tester, item: withPicture);
        final pause = tester.getCenter(find.byIcon(Icons.pause_rounded));
        final heading = tester.getTopLeft(find.text("Today's Programs"));
        expect(heading.dy, greaterThan(pause.dy), reason: 'under the controls');

        // The last program is off the first screen, and the page scrolls to it.
        expect(tester.getTopLeft(find.text('3:00 PM')).dy, greaterThan(844));
        await tester.scrollUntilVisible(find.text('3:00 PM'), 200);
        expect(tester.getTopLeft(find.text('3:00 PM')).dy, lessThan(844));
        expect(tester.takeException(), isNull);
      });

      testWidgets('fits phones of every size, scrolling the short ones', (
        tester,
      ) async {
        for (final size in const [
          Size(390, 844),
          Size(411, 915),
          Size(360, 780),
          Size(360, 640),
          Size(320, 568),
          Size(360, 480),
        ]) {
          await _pump(tester, item: withPicture, size: size);
          expect(tester.takeException(), isNull, reason: '$size');
          expect(find.text("Today's Programs"), findsOneWidget);
        }
      });
    });

    testWidgets('looks right in the light theme too', (tester) async {
      await _pump(tester, theme: ThemeData.light());
      expect(tester.takeException(), isNull);
      expect(find.text('Sokdom'), findsNWidgets(3));
    });

    testWidgets('another station keeps the ordinary player', (tester) async {
      await _pump(
        tester,
        item: const NowPlayingItem(
          id: 'station:4',
          title: 'Hang Meas FM 104.5',
          streamUrl: 'http://x/y.mp3',
          isLive: true,
        ),
      );

      expect(find.text("Today's Programs"), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('the ordinary player goes through all the stations too', (
      tester,
    ) async {
      await _pump(
        tester,
        item: const NowPlayingItem(
          id: 'station:4',
          title: 'Hang Meas FM 104.5',
          streamUrl: 'http://x/y.mp3',
          isLive: true,
        ),
      );

      // Both buttons are live, though a station is played with no list.
      await tester.tap(find.byIcon(Icons.fast_forward_rounded));
      expect(_player.played?.id, 'station:10', reason: 'round to the first');

      _player.played = null;
      await tester.tap(find.byIcon(Icons.fast_rewind_rounded));
      expect(_player.played?.id, 'station:12');
    });
  });
}
