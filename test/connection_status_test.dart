import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/providers/connection_provider.dart';

import 'support/fake_connectivity.dart';

late FakeConnectivitySource _source;
late ProviderContainer _container;

bool get _online => _container.read(connectionStatusProvider);

ConnectionStatus get _status =>
    _container.read(connectionStatusProvider.notifier);

/// Builds the status the way the app does, then lets its first look finish.
Future<void> _start(
  WidgetTester tester, {
  bool online = true,
  Completer<void>? hold,
}) async {
  _source = FakeConnectivitySource(online: online)..hold = hold;
  _container = ProviderContainer(
    overrides: [connectivitySourceProvider.overrideWithValue(_source)],
  );
  _container.read(connectionStatusProvider);
  await _settle(tester);
}

/// Lets what a look awaits go by.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    // Stops the retry timer, and the listeners, before the test ends.
    _container.dispose();
    await _source.close();
  });
}

void main() {
  group('Connection status', () {
    _test('starts online, and a phone that is connected stays so', (
      tester,
    ) async {
      await _start(tester);

      expect(_online, isTrue);
      expect(_source.checks, 1);
    });

    _test('is offline when the first look finds no internet', (tester) async {
      await _start(tester, online: false);

      expect(_online, isFalse);
    });

    _test('is online until the first look has finished', (tester) async {
      final hold = Completer<void>();
      await _start(tester, online: false, hold: hold);

      // Still looking: a good connection must not flash a warning meanwhile.
      expect(_online, isTrue);

      hold.complete();
      await _settle(tester);
      expect(_online, isFalse);
    });

    _test('looks again when the phone\'s connections change', (tester) async {
      await _start(tester);

      _source.online = false;
      _source.connectionsChanged();
      await _settle(tester);
      expect(_online, isFalse);

      _source.online = true;
      _source.connectionsChanged();
      await _settle(tester);
      expect(_online, isTrue);
    });

    _test('while offline keeps looking, and notices by itself that it is '
        'back', (tester) async {
      await _start(tester, online: false);
      expect(_source.checks, 1);

      _source.online = true;
      await tester.pump(const Duration(seconds: 3));
      expect(_source.checks, 1, reason: 'not yet — it looks every few seconds');
      expect(_online, isFalse);

      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(_source.checks, 2);
      expect(_online, isTrue);
    });

    _test('stops looking on its own once it is online again', (tester) async {
      await _start(tester, online: false);
      _source.online = true;
      await tester.pump(const Duration(seconds: 4));
      await _settle(tester);
      final checks = _source.checks;

      await tester.pump(const Duration(minutes: 1));

      expect(_source.checks, checks);
    });

    _test('looks again at once when a request fails to get through', (
      tester,
    ) async {
      await _start(tester);

      _source.online = false;
      unawaited(_status.recheck());
      await _settle(tester);

      expect(_online, isFalse);
    });

    _test('asks one question at a time, however many requests fail', (
      tester,
    ) async {
      final hold = Completer<void>();
      await _start(tester, hold: hold);
      expect(_source.checks, 1);

      // A screen of requests failing together.
      for (var i = 0; i < 5; i++) {
        unawaited(_status.recheck());
      }
      await _settle(tester);
      expect(_source.checks, 1);

      hold.complete();
      await _settle(tester);
      expect(_source.checks, 1);
    });

    _test('looks again when the app comes back to the front', (tester) async {
      await _start(tester);

      _source.online = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);

      expect(_online, isFalse);
    });

    _test('does not look when the app only goes to the background', (
      tester,
    ) async {
      await _start(tester);
      final checks = _source.checks;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _settle(tester);

      expect(_source.checks, checks);
    });

    _test('does not call the phone offline just because it cannot tell', (
      tester,
    ) async {
      await _start(tester);

      _source.error = StateError('no way to check');
      unawaited(_status.recheck());
      await _settle(tester);

      expect(_online, isTrue);
    });
  });
}
