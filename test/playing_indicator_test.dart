import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/providers/audio_levels_provider.dart';
import 'package:e_radio/providers/cover_colors_provider.dart';
import 'package:e_radio/views/widgets/shared/playing_indicator.dart';

/// Says what the sound is, whatever the phone says.
class _Levels extends AudioLevelsController {
  _Levels(this.levels);

  List<double>? levels;

  @override
  List<double>? build() => levels;

  void hear(List<double>? next) => state = next;
}

Widget _host({
  bool reduceMotion = false,
  List<double>? levels,
  List<Color>? cover,
  bool coverColors = false,
}) => ProviderScope(
  overrides: [
    audioLevelsProvider.overrideWith(() => _Levels(levels)),
    playingBarColorsProvider.overrideWithValue(cover),
  ],
  child: MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: PlayingIndicator(
            width: 40,
            height: 22,
            coverColors: coverColors,
          ),
        ),
      ),
    ),
  ),
);

/// The painter is private to the widget, so what it was given is read
/// dynamically.
dynamic _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(PlayingIndicator),
        matching: find.byType(CustomPaint),
      ),
    )
    .painter;

/// Where in its pattern the bars are, 0 to 1; null when they are at rest.
double? _progress(WidgetTester tester) =>
    _painter(tester).progress?.value as double?;

/// How high each bar stands, if they follow the sound.
List<double>? _levels(WidgetTester tester) =>
    (_painter(tester).levels as List<double>?)?.toList();

List<Color> _colors(WidgetTester tester) =>
    _painter(tester).colors as List<Color>;

void main() {
  group('PlayingIndicator', () {
    void animateForThisTest() {
      PlayingIndicator.animate = true;
      addTearDown(() => PlayingIndicator.animate = false);
    }

    testWidgets('keeps the size it is given', (tester) async {
      await tester.pumpWidget(_host());

      expect(tester.getSize(find.byType(PlayingIndicator)), const Size(40, 22));
    });

    testWidgets('rises and falls while it plays, round and round', (
      tester,
    ) async {
      animateForThisTest();
      await tester.pumpWidget(_host());

      final start = _progress(tester);
      expect(start, isNotNull);

      await tester.pump(const Duration(milliseconds: 400));
      final later = _progress(tester)!;
      expect(later, isNot(start));

      // It never runs out: well past one whole pattern it is still going.
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(_progress(tester), isNot(later));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stands still where animation is off, and so can settle', (
      tester,
    ) async {
      await tester.pumpWidget(_host());

      expect(_progress(tester), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('stands still when the phone asks for less motion', (
      tester,
    ) async {
      animateForThisTest();
      await tester.pumpWidget(_host(reduceMotion: true));

      expect(_progress(tester), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('stops when the phone starts asking for less motion', (
      tester,
    ) async {
      animateForThisTest();
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 300));
      expect(_progress(tester), isNotNull);

      await tester.pumpWidget(_host(reduceMotion: true));

      expect(_progress(tester), isNull);
      await tester.pumpAndSettle();
    });
  });

  group('PlayingIndicator following the sound', () {
    void animateForThisTest() {
      PlayingIndicator.animate = true;
      addTearDown(() => PlayingIndicator.animate = false);
    }

    final bass = <double>[1, 0, 0, 0, 0, 0, 0, 0, 0, .5];

    testWidgets('dances to its pattern when there is no sound to follow', (
      tester,
    ) async {
      animateForThisTest();
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 100));

      expect(_levels(tester), isNull);
      expect(_progress(tester), isNotNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('each bar rises to its band of the sound', (tester) async {
      animateForThisTest();
      await tester.pumpWidget(_host(levels: bass));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final shown = _levels(tester)!;
      expect(shown, hasLength(10));
      expect(shown[0], closeTo(1, .02));
      expect(shown[9], closeTo(.5, .02));
      expect(shown.sublist(1, 9), everyElement(closeTo(0, .02)));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rises faster than it falls', (tester) async {
      animateForThisTest();
      await tester.pumpWidget(_host(levels: bass));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayingIndicator)),
      );

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final rose = _levels(tester)![0];

      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      (container.read(audioLevelsProvider.notifier) as _Levels).hear(
        List.filled(10, 0.0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final fell = 1 - _levels(tester)![0];

      expect(rose, greaterThan(.5));
      expect(fell, lessThan(rose));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('goes back to the pattern when the sound cannot be read', (
      tester,
    ) async {
      animateForThisTest();
      await tester.pumpWidget(_host(levels: bass));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_levels(tester), isNotNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlayingIndicator)),
      );

      (container.read(audioLevelsProvider.notifier) as _Levels).hear(null);
      await tester.pump();

      expect(_levels(tester), isNull);
      expect(_progress(tester), isNotNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('does not move for the sound if it was asked not to', (
      tester,
    ) async {
      animateForThisTest();
      await tester.pumpWidget(_host(levels: bass, reduceMotion: true));

      expect(_levels(tester), isNull);
      expect(_progress(tester), isNull);
      await tester.pumpAndSettle();
    });
  });

  group('PlayingIndicator colours', () {
    const cover = [Color(0xFFFF8800), Color(0xFF00AA55)];

    testWidgets('are the cover\'s of what is playing', (tester) async {
      await tester.pumpWidget(_host(cover: cover, coverColors: true));

      expect(_colors(tester), cover);
    });

    testWidgets('are its own pink to cyan until the cover is read', (
      tester,
    ) async {
      await tester.pumpWidget(_host(coverColors: true));

      expect(_colors(tester), hasLength(5));
      expect(_colors(tester).first, const Color(0xFFEC4899));
      expect(_colors(tester).last, const Color(0xFF22D3EE));
    });

    testWidgets('are its own where it was asked not to use the cover\'s', (
      tester,
    ) async {
      await tester.pumpWidget(_host(cover: cover, coverColors: false));

      expect(_colors(tester), isNot(cover));
      expect(_colors(tester), hasLength(5));
    });
  });
}
