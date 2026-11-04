import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/models/program.dart';
import 'package:e_radio/data/repositories/program_repository.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/views/screens/player/now_playing_view.dart';
import 'package:e_radio/views/widgets/shared/periodic_marquee_text.dart';
import 'package:e_radio/views/widgets/shared/playing_indicator.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';

import 'support/test_fonts.dart';

class _FakePlayer extends AudioPlayerController {
  _FakePlayer(this.initial);

  final PlaybackState initial;

  @override
  PlaybackState build() => initial;

  @override
  Stream<Duration> get positionStream =>
      Stream.value(const Duration(minutes: 12, seconds: 32));

  @override
  Stream<Duration?> get durationStream =>
      Stream.value(const Duration(hours: 1, minutes: 12, seconds: 24));
}

Future<void> _pump(
  WidgetTester tester, {
  required NowPlayingItem item,
  Size size = const Size(390, 844),
  PlaybackStatus status = PlaybackStatus.playing,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  // A ProviderScope keeps the overrides it was first built with, so a second
  // call in the same test would still be showing the first item.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        // The sections under a podcast ask the API for the rest of its show;
        // here there is none.
        programsProvider.overrideWith((ref) async => const <Program>[]),
        audioPlayerControllerProvider.overrideWith(
          () => _FakePlayer(PlaybackState(item: item, status: status)),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NowPlayingView(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('matches the live Audio Player structure', (tester) async {
    await _pump(
      tester,
      item: const NowPlayingItem(
        id: 'station:1',
        title: 'APSARA FM97',
        streamUrl: 'https://example.com/live.m3u8',
        isLive: true,
      ),
    );

    expect(find.text('APSARA FM97'), findsNWidgets(2));
    expect(find.text('LIVE'), findsNWidgets(2));
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
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
  });

  group('the music controls', () {
    NowPlayingItem item(String category) => NowPlayingItem(
      id: 'media:1',
      title: 'Track',
      streamUrl: 'https://example.com/1.mp3',
      isLive: false,
      categorySlug: category,
    );

    List<double> xsOf(Iterable<IconData> icons, WidgetTester tester) => [
      for (final icon in icons) tester.getCenter(find.byIcon(icon)).dx,
    ];

    testWidgets('a song has the five visible buttons in one row', (
      tester,
    ) async {
      await _pump(tester, item: item('song'));

      final row = [
        Icons.replay_10_rounded,
        Icons.skip_previous_rounded,
        Icons.pause_rounded,
        Icons.skip_next_rounded,
        Icons.forward_10_rounded,
      ];
      final xs = xsOf(row, tester);
      expect(xs, orderedEquals([...xs]..sort()));
      final ys = {
        for (final icon in row) tester.getCenter(find.byIcon(icon)).dy,
      };
      expect(ys, hasLength(1), reason: 'all on one line');
    });

    testWidgets('the five buttons fit the smallest phones', (tester) async {
      // A layout overflow fails the test on its own.
      await _pump(tester, item: item('song'), size: const Size(320, 640));

      expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
      expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    });

    testWidgets('every song button is big enough to tap', (tester) async {
      await _pump(tester, item: item('song'));

      for (final icon in [
        Icons.replay_10_rounded,
        Icons.skip_previous_rounded,
        Icons.skip_next_rounded,
        Icons.forward_10_rounded,
      ]) {
        final size = tester.getSize(find.widgetWithIcon(IconButton, icon));
        expect(size.width, greaterThanOrEqualTo(40), reason: '$icon');
        expect(size.height, greaterThanOrEqualTo(40), reason: '$icon');
      }
    });

    testWidgets('a podcast episode keeps the ten-second buttons', (
      tester,
    ) async {
      await _pump(tester, item: item('podcast'));

      expect(find.byIcon(Icons.replay_10_rounded), findsOneWidget);
      expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
      expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
      expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    });

    testWidgets('shuffle and repeat stay hidden for songs', (tester) async {
      await _pump(tester, item: item('song'));
      expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
      expect(find.byIcon(Icons.repeat_rounded), findsNothing);
      expect(find.byIcon(Icons.repeat_one_rounded), findsNothing);
    });
  });

  group('the artwork frame', () {
    const station = NowPlayingItem(
      id: 'station:1',
      title: 'APSARA FM97',
      streamUrl: 'https://example.com/live.m3u8',
      isLive: true,
      artworkUrl: 'https://example.com/logo.png',
    );
    final frame = find.byKey(const Key('nowPlayingArtwork'));

    testWidgets('is as wide as the screen, in the 3:4 shape', (tester) async {
      await _pump(tester, item: station);

      final size = tester.getSize(frame);
      expect(size.width, 390);
      expect(size.height, closeTo(520, 0.5)); // 390 wide, 3:4
    });

    testWidgets('shows the picture at the full width, not cropped to fill', (
      tester,
    ) async {
      await _pump(tester, item: station);

      final fits = [
        for (final image in tester.widgetList<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        ))
          image.fit,
      ];
      expect(fits, contains(BoxFit.fitWidth));
    });

    testWidgets('carries the badge, title and heart on its foot, with the '
        'controls under it', (tester) async {
      await _pump(tester, item: station);

      final frameRect = tester.getRect(frame);
      for (final onPicture in [
        find.text('LIVE'),
        find.text('APSARA FM97'),
        find.byIcon(Icons.favorite_border_rounded),
      ]) {
        final inFrame = find.descendant(of: frame, matching: onPicture);
        expect(inFrame, findsOneWidget);
        // On the foot of the picture: in its lower half.
        expect(tester.getCenter(inFrame).dy, greaterThan(frameRect.center.dy));
      }
      expect(
        tester.getTopLeft(find.byIcon(Icons.pause_rounded)).dy,
        greaterThan(frameRect.bottom),
      );
    });

    testWidgets('has a share button right under the heart', (tester) async {
      await _pump(tester, item: station);

      final heart = find.descendant(
        of: frame,
        matching: find.byIcon(Icons.favorite_border_rounded),
      );
      final share = find.descendant(
        of: frame,
        matching: find.byIcon(Icons.share_outlined),
      );
      expect(share, findsOneWidget);
      expect(
        tester.getCenter(share).dx,
        closeTo(tester.getCenter(heart).dx, 0.5),
        reason: 'in the same column',
      );
      final gap = tester.getCenter(share).dy - tester.getCenter(heart).dy;
      expect(gap, inInclusiveRange(28, 40), reason: 'just below, not apart');
      expect(find.byTooltip('Share'), findsOneWidget);
      // On the picture's foot, inside it.
      expect(
        tester.getRect(share).bottom,
        lessThan(tester.getRect(frame).bottom),
      );
    });

    testWidgets('the share button opens the share sheet with what is playing', (
      tester,
    ) async {
      final shared = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          if (call.method == 'share') {
            shared.add(call.arguments as Map<Object?, Object?>);
          }
          return 'dev.fluttercommunity.plus/share/unavailable';
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          null,
        ),
      );
      await _pump(tester, item: station);

      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pump();

      expect(shared, hasLength(1));
      expect(shared.single['text'], 'APSARA FM97');
    });

    const song = NowPlayingItem(
      id: 'media:1',
      title: 'Evening Mix',
      streamUrl: 'https://example.com/1.mp3',
      isLive: false,
      categorySlug: 'song',
      artworkUrl: 'https://example.com/cover.png',
    );

    testWidgets('a song has a settings button right under share', (
      tester,
    ) async {
      await _pump(tester, item: song);

      final share = find.descendant(
        of: frame,
        matching: find.byIcon(Icons.share_outlined),
      );
      final settings = find.descendant(
        of: frame,
        matching: find.byIcon(Icons.settings_outlined),
      );
      expect(settings, findsOneWidget);
      expect(
        tester.getCenter(settings).dx,
        closeTo(tester.getCenter(share).dx, 0.5),
        reason: 'in the same column',
      );
      final gap = tester.getCenter(settings).dy - tester.getCenter(share).dy;
      expect(gap, inInclusiveRange(28, 40), reason: 'just below, not apart');
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(
        tester.getRect(settings).bottom,
        lessThan(tester.getRect(frame).bottom),
        reason: 'inside the picture',
      );
    });

    testWidgets('only a song has the settings button', (tester) async {
      for (final item in [
        station,
        const NowPlayingItem(
          id: 'media:2',
          title: 'Episode',
          streamUrl: 'https://example.com/2.mp3',
          isLive: false,
          categorySlug: 'podcast',
        ),
        const NowPlayingItem(
          id: 'media:3',
          title: 'No category',
          streamUrl: 'https://example.com/3.mp3',
          isLive: false,
        ),
      ]) {
        await _pump(tester, item: item);
        expect(
          find.byIcon(Icons.settings_outlined),
          findsNothing,
          reason: item.id,
        );
        expect(
          find.byIcon(Icons.share_outlined),
          findsOneWidget,
          reason: item.id,
        );
      }

      await _pump(
        tester,
        item: const NowPlayingItem(
          id: 'media:4',
          title: 'Ambient',
          streamUrl: 'https://example.com/4.mp3',
          isLive: false,
          categorySlug: 'ambient-music',
        ),
      );
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('the settings button opens the song play settings', (
      tester,
    ) async {
      await _pump(tester, item: song);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      for (final text in [
        'Settings',
        'Shuffle',
        'Repeat off',
        'Repeat all',
        'Repeat this song',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      // Repeat starts off, shuffle starts off.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Repeat off'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('the sheet turns shuffle on and off', (tester) async {
      await _pump(tester, item: song);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NowPlayingView)),
      );
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(container.read(audioPlayerControllerProvider).shuffle, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.text('Shuffle'));
      await tester.pumpAndSettle();
      expect(container.read(audioPlayerControllerProvider).shuffle, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('the sheet picks the repeat mode and shows which is on', (
      tester,
    ) async {
      await _pump(tester, item: song);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NowPlayingView)),
      );
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      for (final (label, mode) in [
        ('Repeat this song', RepeatMode.one),
        ('Repeat all', RepeatMode.all),
        ('Repeat off', RepeatMode.off),
      ]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(container.read(audioPlayerControllerProvider).repeat, mode);
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, label),
            matching: find.byIcon(Icons.check_rounded),
          ),
          findsOneWidget,
          reason: '$label is the one ticked',
        );
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      }
    });

    testWidgets('the share button needs no sign-in and leaves the heart '
        'alone', (tester) async {
      await _pump(tester, item: station);

      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pump();

      // No sign-in prompt, and the heart is still the empty one.
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    });

    testWidgets('still fills the width on a short phone, keeping the '
        'controls on screen', (tester) async {
      await _pump(tester, item: station, size: const Size(360, 640));

      final size = tester.getSize(frame);
      expect(size.width, 360);
      // Shorter than the design's shape would make it: the controls keep
      // their room.
      expect(size.height, lessThan(360 * 574 / 390));
      expect(size.height, greaterThan(200));
      expect(
        tester.getBottomLeft(find.byIcon(Icons.pause_rounded)).dy,
        lessThan(640),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('shows the real seek times for on-demand audio', (tester) async {
    await _pump(
      tester,
      item: const NowPlayingItem(
        id: 'media:7',
        title: 'Evening Mix',
        streamUrl: 'https://example.com/mix.mp3',
        isLive: false,
      ),
    );
    await tester.pump();

    expect(find.text('12:32'), findsOneWidget);
    expect(find.text('1:12:24'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
  });

  group('the equalizer bars', () {
    const song = NowPlayingItem(
      id: 'media:7',
      title: 'Evening Mix',
      streamUrl: 'https://example.com/mix.mp3',
      isLive: false,
    );
    final wave = find.byKey(const Key('nowPlayingWave'));

    testWidgets('sit on the picture while it plays', (tester) async {
      await _pump(tester, item: song);

      expect(wave, findsOneWidget);
      expect(
        find.descendant(of: wave, matching: find.byType(PlayingIndicator)),
        findsOneWidget,
      );
      // On the picture, not taking room from the controls under it.
      expect(
        tester.getRect(wave).bottom,
        lessThan(
          tester.getRect(find.byKey(const Key('nowPlayingArtwork'))).bottom,
        ),
      );
    });

    testWidgets('are bare: no background behind them', (tester) async {
      await _pump(tester, item: song);

      expect(
        find.descendant(of: wave, matching: find.byType(DecoratedBox)),
        findsNothing,
      );
      expect(
        find.descendant(of: wave, matching: find.byType(ColoredBox)),
        findsNothing,
      );
      // Just the bars, at the left edge the title starts from.
      expect(tester.getSize(wave), const Size(40, 22));
      expect(tester.getTopLeft(wave).dx, 20);
    });

    testWidgets('go while it is paused', (tester) async {
      await _pump(tester, item: song, status: PlaybackStatus.paused);

      expect(wave, findsNothing);
    });
  });

  testWidgets('a long title rests cut off, then slides every 15 seconds', (
    tester,
  ) async {
    // Long enough to take the full 8 s each way, so the slide is over by 32 s.
    final title = List.filled(
      4,
      'ហេតុអ្វីប្រាក់សិករមួយចំនួនមិនទាន់ទុកចិត្តលើការបោះឆ្នោតនេះទេ',
    ).join(' ');
    await _pump(
      tester,
      item: NowPlayingItem(
        id: 'media:9',
        title: title,
        streamUrl: 'https://example.com/talk.mp3',
        isLive: false,
      ),
    );
    // The marquee's own scroll view: the screen has others.
    final sliding = find.byWidgetPredicate(
      (w) =>
          w is SingleChildScrollView &&
          w.scrollDirection == Axis.horizontal &&
          w.physics is NeverScrollableScrollPhysics,
    );

    // Cut off with an ellipsis on the picture (the "About the episode" card
    // under it shows the title whole, and does not slide)…
    final marquees = find.descendant(
      of: find.byType(PeriodicMarqueeText),
      matching: find.text(title),
    );
    expect(marquees, findsOneWidget);
    expect(sliding, findsNothing);
    for (final text in tester.widgetList<Text>(marquees)) {
      expect(text.overflow, TextOverflow.ellipsis);
    }

    // …until 15 seconds in, when it slides to the end and back.
    for (var i = 0; i < 28; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(sliding, findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(sliding, findsOneWidget);

    // Over and resting again (8 s there, 1 s at the end, 8 s back) before the
    // next one is due at 45 s.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(sliding, findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the title in the top bar never slides: one line and a "…"', (
    tester,
  ) async {
    final title = List.filled(
      4,
      'ហេតុអ្វីប្រាក់សិករមួយចំនួនមិនទាន់ទុកចិត្តលើការបោះឆ្នោតនេះទេ',
    ).join(' ');
    await _pump(
      tester,
      item: NowPlayingItem(
        id: 'media:9',
        title: title,
        streamUrl: 'https://example.com/talk.mp3',
        isLive: false,
      ),
    );

    final barTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(title),
    );
    expect(barTitle, findsOneWidget);
    final text = tester.widget<Text>(barTitle);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(PeriodicMarqueeText),
      ),
      findsNothing,
    );

    // Well past the 15 s a marquee would take to start, nothing has moved.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the ⋮ opens the list of what is playing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          // The sections under a podcast ask the API for the rest of its show;
          // here there is none.
          programsProvider.overrideWith((ref) async => const <Program>[]),
          audioPlayerControllerProvider.overrideWith(
            () => _FakePlayer(
              const PlaybackState(item: _mix, status: PlaybackStatus.playing),
            ),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (c, s) => const NowPlayingView()),
              GoRoute(
                path: '/play-list',
                builder: (c, s) =>
                    const Scaffold(body: Text('page /play-list')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('page /play-list'), findsOneWidget);
  });
}

const _mix = NowPlayingItem(
  id: 'media:7',
  title: 'Evening Mix',
  streamUrl: 'https://example.com/mix.mp3',
  isLive: false,
);
