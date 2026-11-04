import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/connection_provider.dart';
import 'package:e_radio/views/widgets/shared/connection_gate.dart';

import 'support/fake_connectivity.dart';

/// Counts how often it is built from scratch — which going offline and coming
/// back must never cause — and has a button to try to press through the page.
class _Page extends StatefulWidget {
  const _Page({required this.onPressed});

  static int created = 0;

  final VoidCallback onPressed;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final _field = TextEditingController();

  @override
  void initState() {
    super.initState();
    _Page.created++;
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('the page'),
      TextButton(onPressed: widget.onPressed, child: const Text('press me')),
      TextField(controller: _field),
    ],
  );
}

late FakeConnectivitySource _source;
var _pressed = 0;

const _screen = Size(390, 844);

Future<void> _pump(
  WidgetTester tester, {
  bool online = true,
  Locale? locale,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  _Page.created = 0;
  _pressed = 0;
  _source = FakeConnectivitySource(online: online);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [connectivitySourceProvider.overrideWithValue(_source)],
      child: MaterialApp(
        theme: theme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => ConnectionGate(child: child!),
        home: Scaffold(
          body: SafeArea(child: _Page(onPressed: () => _pressed++)),
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Lets a look finish, and things slide in or out.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _connectionIs(WidgetTester tester, {required bool online}) async {
  _source.online = online;
  _source.connectionsChanged();
  await _settle(tester);
}

void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    // Takes the app down, stopping the retry timer and the bar's own.
    await tester.pumpWidget(const SizedBox.shrink());
    await _source.close();
  });
}

void main() {
  group('When the phone has no internet', () {
    _test('the app is shown as usual while it is online', (tester) async {
      await _pump(tester);

      expect(find.text('the page'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);
      expect(find.text('Back online'), findsNothing);
    });

    _test('a full page says so', (tester) async {
      await _pump(tester, online: false);

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(
        find.text(
          'Please connect to Wi-Fi or mobile data to continue listening.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try Again'), findsOneWidget);
    });

    _test('and it fills the whole screen', (tester) async {
      await _pump(tester, online: false);

      final cover = find
          .descendant(
            of: find.byType(ConnectionGate),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Material &&
                  w.color ==
                      Theme.of(
                        tester.element(find.byType(ConnectionGate)),
                      ).scaffoldBackgroundColor,
            ),
          )
          .last;
      expect(tester.getRect(cover), Offset.zero & _screen);
    });

    _test('it appears when the connection is lost with the app open', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('No Internet Connection'), findsNothing);

      await _connectionIs(tester, online: false);

      expect(find.text('No Internet Connection'), findsOneWidget);
    });

    _test('nothing under it can be pressed', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('press me'));
      expect(_pressed, 1, reason: 'works while online');

      await _connectionIs(tester, online: false);
      await tester.tap(find.text('press me'), warnIfMissed: false);

      expect(_pressed, 1, reason: 'the page is in the way');
    });

    _test(
      'nothing under it can be reached by a screen reader or the keyboard',
      (tester) async {
        await _pump(tester, online: false);

        final excluded = tester.widget<ExcludeSemantics>(
          find
              .descendant(
                of: find.byType(ConnectionGate),
                matching: find.byType(ExcludeSemantics),
              )
              .first,
        );
        expect(excluded.excluding, isTrue);
        final focus = tester.widget<ExcludeFocus>(
          find
              .descendant(
                of: find.byType(ConnectionGate),
                matching: find.byType(ExcludeFocus),
              )
              .first,
        );
        expect(focus.excluding, isTrue);
      },
    );

    _test('the app keeps its place underneath — it is never rebuilt', (
      tester,
    ) async {
      await _pump(tester);
      await tester.enterText(find.byType(TextField), 'half-typed');
      expect(_Page.created, 1);

      await _connectionIs(tester, online: false);
      await _connectionIs(tester, online: true);
      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);
      await _connectionIs(tester, online: false);

      expect(_Page.created, 1);
      await _connectionIs(tester, online: true);
      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);
      expect(find.text('half-typed'), findsOneWidget);
    });

    _test('Try Again looks again, and lets the app back when it is online', (
      tester,
    ) async {
      await _pump(tester, online: false);
      final looks = _source.checks;

      // The connection is back, but nothing has told the app yet.
      _source.online = true;
      await tester.tap(find.text('Try Again'));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(_source.checks, greaterThan(looks));
      expect(find.text('No Internet Connection'), findsNothing);
      expect(find.text('the page'), findsOneWidget);
    });

    _test('Try Again that finds it still offline keeps the page', (
      tester,
    ) async {
      await _pump(tester, online: false);

      await tester.tap(find.text('Try Again'));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No Internet Connection'), findsOneWidget);
    });

    _test('Try Again shows that it is working, and cannot be pressed twice', (
      tester,
    ) async {
      await _pump(tester, online: false);
      final hold = Completer<void>();
      _source.hold = hold;
      final looks = _source.checks;

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Try Again'), warnIfMissed: false);
      await tester.pump();
      expect(_source.checks, looks + 1, reason: 'one look at a time');

      hold.complete();
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    _test('it comes back by itself when the connection does, saying so for a '
        'moment', (tester) async {
      await _pump(tester, online: false);

      await _connectionIs(tester, online: true);

      expect(find.text('No Internet Connection'), findsNothing);
      expect(find.text('the page'), findsOneWidget);
      expect(find.text('Back online'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);
      expect(find.text('Back online'), findsNothing);
    });

    _test('gives the app its room back once "Back online" has gone', (
      tester,
    ) async {
      await _pump(tester);
      final before = tester.getTopLeft(find.text('the page')).dy;

      await _connectionIs(tester, online: false);
      await _connectionIs(tester, online: true);
      expect(
        tester.getTopLeft(find.text('the page')).dy,
        greaterThan(before),
        reason: 'pushed down by the bar',
      );
      await tester.pump(const Duration(seconds: 2));
      await _settle(tester);

      expect(tester.getTopLeft(find.text('the page')).dy, before);
    });

    _test('losing the connection again cuts "Back online" short', (
      tester,
    ) async {
      await _pump(tester, online: false);
      await _connectionIs(tester, online: true);
      expect(find.text('Back online'), findsOneWidget);

      await _connectionIs(tester, online: false);

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.text('Back online'), findsNothing);
      // The old "back online" timer must not take anything down later.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('No Internet Connection'), findsOneWidget);
    });

    _test('speaks Khmer when the app is in Khmer', (tester) async {
      await _pump(tester, online: false, locale: const Locale('km'));

      expect(find.text('គ្មានការតភ្ជាប់អ៊ីនធឺណិត'), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);
    });

    _test('takes the colours of a dark app', (tester) async {
      await _pump(tester, online: false, theme: ThemeData.dark());

      final cover = find
          .descendant(
            of: find.byType(ConnectionGate),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Material &&
                  w.color == ThemeData.dark().scaffoldBackgroundColor,
            ),
          )
          .last;
      expect(tester.getRect(cover), Offset.zero & _screen);
    });
  });
}
