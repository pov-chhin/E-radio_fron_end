import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/user_profile.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/auth_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/widgets/shared/app_preloader.dart';
import 'package:e_radio/views/widgets/shared/eradio_logo_mark.dart';

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

Future<void> _pump(
  WidgetTester tester, {
  int? hour,
  bool signedIn = false,
  bool reduceMotion = false,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 844),
  required VoidCallback onDone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (signedIn) authControllerProvider.overrideWith(_SignedIn.new),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: AppPreloader(hour: hour, onDone: onDone),
      ),
    ),
  );
}

void main() {
  group('the greeting', () {
    for (final (hour, greeting) in [
      (6, 'Good morning, Guest'),
      (11, 'Good morning, Guest'),
      (12, 'Good afternoon, Guest'),
      (17, 'Good afternoon, Guest'),
      (18, 'Good evening, Guest'),
      (23, 'Good evening, Guest'),
    ]) {
      testWidgets('at $hour:00 is "$greeting"', (tester) async {
        await _pump(tester, hour: hour, onDone: () {});
        await tester.pump(const Duration(milliseconds: 2000));

        expect(find.text(greeting), findsOneWidget);
        await tester.pumpAndSettle();
      });
    }

    testWidgets('names the person who is signed in', (tester) async {
      await _pump(tester, hour: 9, signedIn: true, onDone: () {});
      await tester.pump(const Duration(milliseconds: 2000));

      expect(find.text('Good morning, Pov'), findsOneWidget);
      expect(find.textContaining('Guest'), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('is in Khmer when the app is', (tester) async {
      await _pump(tester, hour: 9, onDone: () {}, locale: const Locale('km'));
      await tester.pump(const Duration(milliseconds: 2000));

      expect(find.text('អរុណសួស្តី ភ្ញៀវ'), findsOneWidget);
      expect(find.text('សូមស្វាគមន៍មកកាន់'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('the preloader', () {
    testWidgets('shows the logo and welcomes to AMS ERadio', (tester) async {
      await _pump(tester, hour: 9, onDone: () {});
      await tester.pump(const Duration(milliseconds: 2000));

      expect(find.byType(EradioLogoMark), findsOneWidget);
      expect(find.text('Welcome to'), findsOneWidget);
      expect(find.text('AMS ERadio'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('has nothing of the welcome on screen when it starts', (
      tester,
    ) async {
      await _pump(tester, hour: 9, onDone: () {});

      // At the first frame the words are there but still transparent.
      final welcome = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Welcome to'),
          matching: find.byType(Opacity),
        ),
      );
      expect(welcome.opacity, 0);
      await tester.pumpAndSettle();
    });

    testWidgets('is done once, after about three seconds', (tester) async {
      var done = 0;
      await _pump(tester, hour: 9, onDone: () => done++);

      await tester.pump(const Duration(milliseconds: 2500));
      expect(done, 0);

      await tester.pump(const Duration(milliseconds: 400));
      expect(done, 1);

      await tester.pump(const Duration(seconds: 3));
      expect(done, 1);
    });

    testWidgets('a tap skips ahead', (tester) async {
      var done = 0;
      await _pump(tester, hour: 9, onDone: () => done++);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('AMS ERadio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(done, 1);
    });

    testWidgets('with animations off, everything is there at once and it is '
        'over quickly', (tester) async {
      var done = 0;
      await _pump(tester, hour: 9, reduceMotion: true, onDone: () => done++);

      expect(find.text('Good morning, Guest'), findsOneWidget);
      final welcome = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('Welcome to'),
          matching: find.byType(Opacity),
        ),
      );
      expect(welcome.opacity, 1);

      await tester.pump(const Duration(milliseconds: 1300));
      expect(done, 1);
    });

    testWidgets('fits the smallest phones', (tester) async {
      await _pump(
        tester,
        hour: 20,
        signedIn: true,
        size: const Size(320, 568),
        onDone: () {},
      );
      await tester.pump(const Duration(milliseconds: 2000));

      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });
  });
}
