import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/views/widgets/shared/periodic_marquee_text.dart';

const _long = 'Time to rise feat. Master Kong and the whole of the band';
const _style = TextStyle(fontSize: 16);

/// The beat the mechanism tests below run on: slow enough that a slide (up to
/// 17 s for so long a title in the test font) is over well before the next.
const _beat = Duration(seconds: 25);

/// [interval] left out is the widget's own — what the mini player gets.
Widget _host(String text, {double width = 120, Duration? interval = _beat}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: interval == null
                ? PeriodicMarqueeText(text, style: _style)
                : PeriodicMarqueeText(text, style: _style, interval: interval),
          ),
        ),
      ),
    );

Finder get _sliding => find.byType(SingleChildScrollView);

/// Runs [total] of fake time in half-second steps, so timers and frames both
/// get their turn.
Future<void> _run(WidgetTester tester, Duration total) async {
  var left = total;
  const step = Duration(milliseconds: 500);
  while (left > Duration.zero) {
    final next = left < step ? left : step;
    await tester.pump(next);
    left -= next;
  }
}

/// Leaves nothing pending: the widget is gone and any wait it had has run out.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('PeriodicMarqueeText as the mini player has it', () {
    // 30 characters at 16 px in the test font: 80 px too wide for 400, which
    // takes 2 s to cross — a 5 s slide, there, a pause and back.
    const title = 'Time to rise feat. Master Kong';

    testWidgets('slides every 15 seconds', (tester) async {
      await tester.pumpWidget(_host(title, width: 400, interval: null));

      await _run(tester, const Duration(seconds: 14));
      expect(_sliding, findsNothing);

      await _run(tester, const Duration(seconds: 1));
      await tester.pump();
      expect(_sliding, findsOneWidget);

      // Over and resting again, cut off with an ellipsis…
      await _run(tester, const Duration(seconds: 6));
      expect(_sliding, findsNothing);
      expect(
        tester.widget<Text>(find.text(title)).overflow,
        TextOverflow.ellipsis,
      );

      // …until the next one, 15 seconds after the last began.
      await _run(tester, const Duration(seconds: 9));
      await tester.pump();
      expect(_sliding, findsOneWidget);
      await _run(tester, const Duration(seconds: 6));
      await _teardown(tester);
    });

    testWidgets('a title that fits still never moves', (tester) async {
      await tester.pumpWidget(_host(title, width: 600, interval: null));

      await _run(tester, const Duration(seconds: 60));

      expect(_sliding, findsNothing);
      await _teardown(tester);
    });
  });

  group('PeriodicMarqueeText', () {
    testWidgets('a title that fits is plain text and never moves', (
      tester,
    ) async {
      await tester.pumpWidget(_host('Short', width: 200));

      await _run(tester, const Duration(seconds: 120));

      expect(_sliding, findsNothing);
      expect(find.text('Short'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('a long title rests with an ellipsis', (tester) async {
      await tester.pumpWidget(_host(_long));

      final text = tester.widget<Text>(find.text(_long));
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
      expect(_sliding, findsNothing);

      // Not before the 25 seconds are up.
      await _run(tester, const Duration(seconds: 24));
      expect(_sliding, findsNothing);
      await _teardown(tester);
    });

    testWidgets('after 25 seconds it slides to its end and back, once', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_long));
      await _run(tester, const Duration(seconds: 25));
      await tester.pump();

      expect(_sliding, findsOneWidget);
      final controller = tester
          .widget<SingleChildScrollView>(_sliding)
          .controller!;

      // Part way along.
      await _run(tester, const Duration(seconds: 1));
      expect(controller.offset, greaterThan(0));
      expect(controller.offset, lessThan(controller.position.maxScrollExtent));

      // At the end, the last words are showing.
      var peak = 0.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (!controller.hasClients) break;
        if (controller.offset > peak) peak = controller.offset;
      }
      expect(peak, greaterThan(0));

      // Then it is back at rest, cut off again.
      await _run(tester, const Duration(seconds: 10));
      expect(_sliding, findsNothing);
      expect(
        tester.widget<Text>(find.text(_long)).overflow,
        TextOverflow.ellipsis,
      );
      await _teardown(tester);
    });

    testWidgets('it slides all the way to the last word', (tester) async {
      await tester.pumpWidget(_host(_long));
      await _run(tester, const Duration(seconds: 25));
      await tester.pump();

      final controller = tester
          .widget<SingleChildScrollView>(_sliding)
          .controller!;
      final end = controller.position.maxScrollExtent;
      expect(end, greaterThan(0));

      var peak = 0.0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (!controller.hasClients) break;
        if (controller.offset > peak) peak = controller.offset;
      }
      expect(peak, closeTo(end, 0.5));
      await _run(tester, const Duration(seconds: 10));
      await _teardown(tester);
    });

    testWidgets('and slides again 25 seconds later', (tester) async {
      await tester.pumpWidget(_host(_long));

      await _run(tester, const Duration(seconds: 25));
      await tester.pump();
      expect(_sliding, findsOneWidget);

      // A slide is 8 s there, 1 s at the end and 8 s back: over, and resting,
      // before the next one is due at 50 s.
      await _run(tester, const Duration(seconds: 18));
      expect(_sliding, findsNothing);

      await _run(tester, const Duration(seconds: 7));
      await tester.pump();
      expect(_sliding, findsOneWidget);
      await _run(tester, const Duration(seconds: 18));
      expect(_sliding, findsNothing);
      await _teardown(tester);
    });

    testWidgets('a new title cuts a slide short and waits 25 seconds again', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_long));
      await _run(tester, const Duration(seconds: 25));
      await tester.pump();
      expect(_sliding, findsOneWidget);

      const next = 'Another very long title that does not fit either, no';
      await tester.pumpWidget(_host(next));
      expect(_sliding, findsNothing);
      expect(find.text(next), findsOneWidget);

      await _run(tester, const Duration(seconds: 24));
      expect(_sliding, findsNothing);
      await _run(tester, const Duration(seconds: 1));
      await tester.pump();
      expect(_sliding, findsOneWidget);
      await _run(tester, const Duration(seconds: 18));
      await _teardown(tester);
    });

    testWidgets('a title that grows past its space starts to slide', (
      tester,
    ) async {
      await tester.pumpWidget(_host('Short', width: 120));
      await _run(tester, const Duration(seconds: 30));
      expect(_sliding, findsNothing);

      await tester.pumpWidget(_host(_long, width: 120));
      await _run(tester, const Duration(seconds: 25));
      await tester.pump();
      expect(_sliding, findsOneWidget);
      await _run(tester, const Duration(seconds: 12));
      await _teardown(tester);
    });
  });
}
