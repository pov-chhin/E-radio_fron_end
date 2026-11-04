import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/data/models/program.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/views/widgets/podcasts/podcast_artwork_stack.dart';
import 'package:e_radio/views/widgets/podcasts/podcast_card.dart';

import 'support/test_fonts.dart';

Future<void> _pump(
  WidgetTester tester,
  Program program, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: PodcastCard(program: program, onTap: () {}),
        ),
      ),
    ),
  );
}

Program _show({int? episodes}) => Program(
  id: '1',
  name: 'Mix - Dolly Babe - Pink Blush (Official Audio)',
  hostName: 'Saucy Santana',
  categoryName: 'Sexy',
  episodeCount: episodes,
);

void main() {
  setUpAll(loadTestFonts);

  testWidgets('says how many episodes the show has, on its cover', (
    tester,
  ) async {
    await _pump(tester, _show(episodes: 6));

    expect(find.text('6 EP'), findsOneWidget);
    final cover = tester.getRect(find.byType(PodcastArtworkStack));
    final badge = tester.getRect(find.text('6 EP'));
    expect(cover.contains(badge.center), isTrue);
  });

  testWidgets('sits in the bottom-right corner of the picture', (tester) async {
    await _pump(tester, _show(episodes: 6));

    final cover = tester.getRect(find.byType(PodcastArtworkStack));
    final pill = tester.getRect(
      find
          .ancestor(of: find.text('6 EP'), matching: find.byType(DecoratedBox))
          .first,
    );
    // 8 in from the right edge and the bottom of the cover.
    expect(cover.right - pill.right, 8);
    expect(cover.bottom - pill.bottom, 8);
  });

  testWidgets('is in Khmer when the app is', (tester) async {
    await _pump(tester, _show(episodes: 12), locale: const Locale('km'));

    expect(find.text('12 ភាគ'), findsOneWidget);
    expect(find.text('12 EP'), findsNothing);
  });

  testWidgets('is left off a show that does not say, or has none', (
    tester,
  ) async {
    await _pump(tester, _show());
    expect(find.textContaining('EP'), findsNothing);

    await _pump(tester, _show(episodes: 0));
    expect(find.textContaining('EP'), findsNothing);
  });

  testWidgets('does not change the card\'s size', (tester) async {
    await _pump(tester, _show());
    final without = tester.getSize(find.byType(PodcastCard));

    await _pump(tester, _show(episodes: 6));
    expect(tester.getSize(find.byType(PodcastCard)), without);
  });

  testWidgets('stays small when the system font is large', (tester) async {
    await _pump(tester, _show(episodes: 128), textScale: 1.6);

    expect(tester.takeException(), isNull);
    final cover = tester.getRect(find.byType(PodcastArtworkStack));
    final badge = tester.getRect(find.text('128 EP'));
    expect(badge.height, lessThan(20));
    expect(cover.contains(badge.bottomRight), isTrue);
  });
}
