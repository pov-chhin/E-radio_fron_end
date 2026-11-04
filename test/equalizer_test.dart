import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/equalizer_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/widgets/player/equalizer_sheet.dart';
import 'package:e_radio/views/widgets/player/song_play_settings_sheet.dart';

import 'support/test_fonts.dart';

class _FakePlayer extends AudioPlayerController {
  @override
  PlaybackState build() => const PlaybackState();
}

/// An equalizer that already knows its five bands, and notes the gains it is
/// told to set.
class _ReadyEqualizer extends EqualizerController {
  final gainsSet = <(int, double)>[];

  @override
  EqualizerState build() => const EqualizerState(
    supported: true,
    ready: true,
    enabled: true,
    preset: 'bass_boost',
    gains: [6, 4, 0, 0, 0],
    frequencies: [60, 230, 910, 3600, 14000],
  );

  @override
  void setGain(int band, double decibels) => gainsSet.add((band, decibels));
}

Future<void> _pump(
  WidgetTester tester,
  Widget sheet, {
  AndroidEqualizer? equalizer,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        audioPlayerControllerProvider.overrideWith(_FakePlayer.new),
        equalizerEffectProvider.overrideWithValue(equalizer),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: sheet),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  group('presets', () {
    final bass = kEqualizerPresets.firstWhere((p) => p.id == 'bass_boost');

    test('five bands take the curve as it is', () {
      expect(bass.gainsFor(5, min: -15, max: 15), [6, 4, 0, 0, 0]);
    });

    test(
      'other band counts stretch the curve from the low end to the high',
      () {
        expect(bass.gainsFor(3, min: -15, max: 15), [6, 0, 0]);
        final ten = bass.gainsFor(10, min: -15, max: 15);
        expect(ten, hasLength(10));
        expect(ten.first, 6);
        expect(ten.last, 0);
        // Falling steadily, never rising, from the boosted bass.
        for (var i = 1; i < ten.length; i++) {
          expect(ten[i], lessThanOrEqualTo(ten[i - 1]));
        }
      },
    );

    test('a single band gets the middle of the curve', () {
      expect(bass.gainsFor(1, min: -15, max: 15), [0]);
    });

    test('gains stay within what the phone allows', () {
      expect(bass.gainsFor(5, min: -3, max: 3), [3, 3, 0, 0, 0]);
    });

    test('flat is flat, and every preset has an id of its own', () {
      expect(
        kEqualizerPresets.first.gainsFor(5, min: -15, max: 15),
        everyElement(0),
      );
      final ids = kEqualizerPresets.map((p) => p.id).toSet();
      expect(ids, hasLength(kEqualizerPresets.length));
      expect(ids, isNot(contains(kCustomPreset)));
    });
  });

  group('song settings', () {
    testWidgets('offer no equalizer where the phone has none', (tester) async {
      await _pump(tester, SongPlaySettingsSheet(onEqualizer: () {}));

      expect(find.text('Shuffle'), findsOneWidget);
      expect(find.text('Equalizer'), findsNothing);
    });

    testWidgets('offer the equalizer on Android, and open it', (tester) async {
      var opened = 0;
      await _pump(
        tester,
        SongPlaySettingsSheet(onEqualizer: () => opened++),
        equalizer: AndroidEqualizer(),
      );

      await tester.tap(find.text('Equalizer'));
      expect(opened, 1);
    });

    testWidgets('leave the row out when nothing can open it', (tester) async {
      await _pump(
        tester,
        const SongPlaySettingsSheet(),
        equalizer: AndroidEqualizer(),
      );

      expect(find.text('Equalizer'), findsNothing);
    });
  });

  group('equalizer sheet', () {
    testWidgets('asks for a song first until the bands are known', (
      tester,
    ) async {
      await _pump(
        tester,
        const EqualizerSheet(),
        equalizer: AndroidEqualizer(),
      );

      expect(find.text('Equalizer'), findsOneWidget);
      expect(find.text('Play a song to adjust the equalizer.'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      // The switch can't be flipped before there is anything to switch.
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('shows every band with its gain and frequency', (tester) async {
      await _pump(
        tester,
        const EqualizerSheet(),
        overrides: [equalizerProvider.overrideWith(_ReadyEqualizer.new)],
      );

      expect(tester.takeException(), isNull);
      for (final label in ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('+6.0 dB'), findsOneWidget);
      expect(find.text('+4.0 dB'), findsOneWidget);
      expect(find.text('Bass boost'), findsWidgets);
    });

    testWidgets('dragging a band up boosts that band', (tester) async {
      await _pump(
        tester,
        const EqualizerSheet(),
        overrides: [equalizerProvider.overrideWith(_ReadyEqualizer.new)],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EqualizerSheet)),
      );
      final controller =
          container.read(equalizerProvider.notifier) as _ReadyEqualizer;

      final sliders = find.byWidgetPredicate(
        (widget) =>
            widget is GestureDetector && widget.onVerticalDragUpdate != null,
      );
      expect(sliders, findsNWidgets(5));

      // The middle band sits at 0 dB, halfway; dragging up raises it.
      await tester.drag(sliders.at(2), const Offset(0, -50));
      await tester.pump();

      expect(controller.gainsSet, isNotEmpty);
      expect(controller.gainsSet.every((set) => set.$1 == 2), isTrue);
      expect(controller.gainsSet.last.$2, greaterThan(0));
    });
  });
}
