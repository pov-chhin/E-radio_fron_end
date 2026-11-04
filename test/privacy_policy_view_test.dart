import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/views/screens/profile/privacy_policy_view.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';

import 'support/test_fonts.dart';

Future<void> _pump(WidgetTester tester, {Locale? locale}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PrivacyPolicyView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('shows the title and the policy text, centred', (tester) async {
    await _pump(tester);

    expect(find.text('Privacy Policy'), findsOneWidget); // app bar title
    final text = tester.widget<Text>(find.textContaining('(GDPR)'));
    expect(text.textAlign, TextAlign.center);
    expect(text.data, contains('Legal Information'));
    expect(text.data, contains('About the Site'));
    expect(text.data, contains('Definition:'));
  });

  testWidgets('scrolls to the last line', (tester) async {
    await _pump(tester);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('provided by the publisher.'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing, reason: 'no route beneath');
  });

  testWidgets('keeps the policy in English but titles the screen in Khmer', (
    tester,
  ) async {
    await _pump(tester, locale: const Locale('km'));

    expect(find.text('គោលការណ៍ឯកជនភាព'), findsOneWidget);
    expect(find.textContaining('Privacy Policy (GDPR)'), findsOneWidget);
  });
}
