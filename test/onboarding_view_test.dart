import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/providers/onboarding_interests_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/screens/onboarding/onboarding_view.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';

Future<void> _pumpOnboarding(WidgetTester tester) async {
  // A phone-sized screen — the page layouts are proportional to its height.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingView(),
      ),
    ),
  );
}

/// Lets the splash's 1.8 s auto-advance fire and the page animation finish.
Future<void> _pastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1900));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on the splash, then moves on to Discover by itself', (
    tester,
  ) async {
    await _pumpOnboarding(tester);

    expect(find.text('E-RADIO'), findsOneWidget);

    await _pastSplash(tester);

    expect(find.text('Discover Live Radio'), findsOneWidget);
    expect(find.text('Skip'), findsWidgets);
  });

  testWidgets('a picked genre turns to a check mark and is remembered', (
    tester,
  ) async {
    await _pumpOnboarding(tester);
    await _pastSplash(tester);

    await tester.drag(find.byType(PageView), const Offset(-300, 0)); // one page
    await tester.pumpAndSettle();

    expect(find.text('Pick Your Favorites'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(OnboardingView)),
    );
    expect(container.read(onboardingInterestsProvider), {'music'});

    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(container.read(onboardingInterestsProvider), isEmpty);
  });

  testWidgets('Continue comes in with the first pick and leads to the last '
      'page with its Let\'s Go! button', (tester) async {
    await _pumpOnboarding(tester);
    await _pastSplash(tester);
    await tester.drag(find.byType(PageView), const Offset(-300, 0)); // one page
    await tester.pumpAndSettle();

    // Nothing picked yet: no Continue (Figma "Onboarding 3").
    expect(find.text('Continue'), findsNothing);

    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('One Tap to Play'), findsOneWidget);
    expect(find.text("Let's Go!"), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  testWidgets('Continue goes again when the last pick is put back', (
    tester,
  ) async {
    await _pumpOnboarding(tester);
    await _pastSplash(tester);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Music'));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('swiping past the genres still reaches Let\'s Go!', (
    tester,
  ) async {
    await _pumpOnboarding(tester);
    await _pastSplash(tester);

    // Not the chips' area, which scrolls on its own: the strip above the
    // headline's left edge is the pages'.
    await tester.dragFrom(const Offset(20, 300), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(20, 650), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text('One Tap to Play'), findsOneWidget);
    expect(find.text("Let's Go!"), findsOneWidget);
  });

  testWidgets('a tap on the splash moves on at once', (tester) async {
    await _pumpOnboarding(tester);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();

    expect(find.text('Discover Live Radio'), findsOneWidget);
  });
}
