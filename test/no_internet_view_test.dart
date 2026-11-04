import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/connection_provider.dart';
import 'package:e_radio/views/widgets/shared/no_internet_view.dart';
import 'package:e_radio/views/widgets/shared/retry_view.dart';

import 'support/fake_connectivity.dart';

late FakeConnectivitySource _source;

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  bool online = true,
  ThemeData? theme,
  Locale? locale,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  _source = FakeConnectivitySource(online: online);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [connectivitySourceProvider.overrideWithValue(_source)],
      child: MaterialApp(
        theme: theme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: page),
      ),
    ),
  );
  await _settle(tester);
  // And a change of theme finish fading in.
  await tester.pump(const Duration(milliseconds: 400));
}

/// Lets a look at the connection finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<void> _connectionIs(WidgetTester tester, {required bool online}) async {
  _source.online = online;
  _source.connectionsChanged();
  await _settle(tester);
}

void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    // Takes the page down, stopping the retry timer while offline.
    await tester.pumpWidget(const SizedBox.shrink());
    await _source.close();
  });
}

void main() {
  group('No Internet Connection page', () {
    _test('has the title, the message and Try Again', (tester) async {
      await _pump(tester, NoInternetView(onRetry: () {}));

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(
        find.text(
          'Please connect to Wi-Fi or mobile data to continue listening.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try Again'), findsOneWidget);
    });

    _test('Try Again tries again', (tester) async {
      var retried = 0;
      await _pump(tester, NoInternetView(onRetry: () => retried++));

      await tester.tap(find.text('Try Again'));

      expect(retried, 1);
    });

    _test('draws the Wi-Fi mark above the words, in the middle', (
      tester,
    ) async {
      await _pump(tester, NoInternetView(onRetry: () {}));

      final mark = find.descendant(
        of: find.byType(NoInternetView),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter != null,
        ),
      );
      expect(mark, findsOneWidget);
      final markBox = tester.getRect(mark);
      expect(markBox.width, closeTo(156 * 0.72, 0.01));
      expect(markBox.height, closeTo(172 * 0.72, 0.01));
      expect(markBox.center.dx, closeTo(195, 0.5), reason: 'centred on 390');
      expect(
        markBox.bottom,
        lessThan(tester.getRect(find.text('No Internet Connection')).top),
      );
    });

    _test('keeps the title, message and button in one centred column', (
      tester,
    ) async {
      await _pump(tester, NoInternetView(onRetry: () {}));

      for (final finder in [
        find.text('No Internet Connection'),
        find.text('Try Again'),
      ]) {
        expect(tester.getCenter(finder).dx, closeTo(195, 0.5));
      }
      // Title, then message, then button, top to bottom.
      final title = tester.getRect(find.text('No Internet Connection')).top;
      final message = tester
          .getRect(find.textContaining('Please connect to Wi-Fi'))
          .top;
      final button = tester.getRect(find.text('Try Again')).top;
      expect(title, lessThan(message));
      expect(message, lessThan(button));
    });

    _test('has a dark button on a light page and a light one on a dark page', (
      tester,
    ) async {
      Color? buttonFill() => tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.text('Try Again'),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color;

      await _pump(
        tester,
        NoInternetView(onRetry: () {}),
        theme: ThemeData.light(),
      );
      final onLight = buttonFill()!;
      await _pump(
        tester,
        NoInternetView(onRetry: () {}),
        theme: ThemeData.dark(),
      );
      final onDark = buttonFill()!;

      expect(onLight.computeLuminance(), lessThan(.2));
      expect(onDark.computeLuminance(), greaterThan(.6));
    });

    _test('speaks Khmer when the app is in Khmer', (tester) async {
      await _pump(
        tester,
        NoInternetView(onRetry: () {}),
        locale: const Locale('km'),
      );

      expect(find.text('គ្មានការតភ្ជាប់អ៊ីនធឺណិត'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);
    });

    _test('tries again by itself when the connection comes back', (
      tester,
    ) async {
      var retried = 0;
      await _pump(
        tester,
        NoInternetView(onRetry: () => retried++),
        online: false,
      );
      expect(retried, 0);

      await _connectionIs(tester, online: true);

      expect(retried, 1);
    });

    _test('shows that it is working, and ignores taps meanwhile', (
      tester,
    ) async {
      var retried = 0;
      await _pump(tester, NoInternetView(onRetry: () => retried++, busy: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Try Again'), warnIfMissed: false);
      expect(retried, 0);
    });

    _test('keeps the button the same size while it is working', (tester) async {
      Size buttonSize() => tester.getSize(
        find
            .ancestor(
              of: find.text('Try Again'),
              matching: find.byType(InkWell),
            )
            .first,
      );

      await _pump(tester, NoInternetView(onRetry: () {}));
      final idle = buttonSize();
      await _pump(tester, NoInternetView(onRetry: () {}, busy: true));

      expect(buttonSize(), idle);
    });

    _test('can leave trying again to the one who asked for the page', (
      tester,
    ) async {
      var retried = 0;
      await _pump(
        tester,
        NoInternetView(onRetry: () => retried++, retryWhenBack: false),
        online: false,
      );

      await _connectionIs(tester, online: true);

      expect(retried, 0);
    });

    _test('does not try again just because it went offline', (tester) async {
      var retried = 0;
      await _pump(tester, NoInternetView(onRetry: () => retried++));

      await _connectionIs(tester, online: false);

      expect(retried, 0);
    });

    _test('does not try again when the connection never left', (tester) async {
      var retried = 0;
      await _pump(tester, NoInternetView(onRetry: () => retried++));

      await _connectionIs(tester, online: true);

      expect(retried, 0);
    });
  });

  group('A page that failed to load', () {
    _test('offers a plain Retry while the phone is online', (tester) async {
      var retried = 0;
      await _pump(tester, RetryView(onRetry: () => retried++));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);

      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    _test('shows the No Internet Connection page while it is offline', (
      tester,
    ) async {
      await _pump(tester, RetryView(onRetry: () {}), online: false);

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    _test('switches to the page when the connection is lost', (tester) async {
      await _pump(tester, RetryView(onRetry: () {}));
      expect(find.text('Retry'), findsOneWidget);

      await _connectionIs(tester, online: false);

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    _test('loads again by itself, once, when the connection returns', (
      tester,
    ) async {
      var retried = 0;
      await _pump(tester, RetryView(onRetry: () => retried++), online: false);

      await _connectionIs(tester, online: true);

      expect(retried, 1);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);
    });
  });
}
