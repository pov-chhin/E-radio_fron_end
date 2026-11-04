import 'dart:async';

import 'package:e_radio/data/services/api_client.dart';
import 'package:e_radio/data/services/image_warmer.dart';
import 'package:e_radio/data/services/list_cache.dart';
import 'package:e_radio/providers/list_cache_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/providers/station_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request from [reply], so a test decides when (and whether)
/// the "network" responds.
class _FakeApi extends ApiClient {
  _FakeApi(this.reply);

  final Future<dynamic> Function() reply;
  int calls = 0;

  @override
  Future<dynamic> get(String path, {String? token}) {
    calls++;
    return reply();
  }
}

class _FakeWarmer extends ImageWarmer {
  final warmed = <String?>[];

  @override
  Future<void> warm(Iterable<String?> urls) async => warmed.addAll(urls);
}

/// Where the stations' stored top is filed (their API path).
const _storedKey = 'list_cache.v1./stations';

Map<String, dynamic> _station(int n) => {
  'id': 's$n',
  'name': 'Station $n',
  'stream_url': 'https://example.com/$n.mp3',
  'cover_url': 'https://example.com/$n.png',
};

Map<String, dynamic> _reply(int count) => {
  'data': [for (var i = 1; i <= count; i++) _station(i)],
};

late _FakeApi _api;
late _FakeWarmer _warmer;

/// A container over a fake API and warmer. [stored] stations are already on
/// the device, as if left by an earlier launch; [prefs] adds raw entries.
Future<ProviderContainer> _setup({
  required Future<dynamic> Function() reply,
  int stored = 0,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  if (stored > 0) {
    await ListCache(
      sharedPrefs,
    ).write('/stations', [for (var i = 1; i <= stored; i++) _station(i)]);
  }
  return _setupWith(sharedPrefs, reply: reply);
}

/// Like [_setup], over preferences the test has already filled itself.
Future<ProviderContainer> _setupWith(
  SharedPreferences sharedPrefs, {
  required Future<dynamic> Function() reply,
}) async {
  _api = _FakeApi(reply);
  _warmer = _FakeWarmer();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      apiClientProvider.overrideWithValue(_api),
      imageWarmerProvider.overrideWithValue(_warmer),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

List<Map<String, dynamic>>? _storedTop(ProviderContainer container) =>
    container.read(listCacheProvider).read('/stations');

void main() {
  test('with nothing stored it loads from the network, then keeps only the '
      'top of the list', () async {
    final container = await _setup(reply: () async => _reply(25));

    final stations = await container.read(stationsProvider.future);

    expect(stations, hasLength(25), reason: 'the screen gets the whole list');
    expect(_api.calls, 1);
    await pumpEventQueue();
    expect(
      _storedTop(container),
      hasLength(kTopCacheLimit),
      reason: 'but only the top is stored',
    );
    expect(
      _warmer.warmed,
      [for (var i = 1; i <= kTopCacheLimit; i++) 'https://example.com/$i.png'],
      reason: 'and only the top pictures are fetched ahead of time',
    );
  });

  test('a stored list is there at once, then the fresh one replaces it '
      'quietly', () async {
    final fresh = Completer<dynamic>();
    final container = await _setup(reply: () => fresh.future, stored: 3);

    // Synchronously available — no loading state, no waiting on the network.
    final first = container.read(stationsProvider);
    expect(first.hasValue, isTrue);
    expect(first.isLoading, isFalse);
    expect(first.requireValue.map((s) => s.id), ['s1', 's2', 's3']);

    // The fetch is already under way behind it.
    expect(_api.calls, 1);

    fresh.complete(_reply(5));
    await pumpEventQueue();

    final after = container.read(stationsProvider);
    expect(after.requireValue, hasLength(5));
    expect(after.isLoading, isFalse);
    expect(_storedTop(container), hasLength(5));
  });

  test('offline, the stored list stays and no error appears', () async {
    final container = await _setup(
      reply: () async => throw Exception('no route to host'),
      stored: 3,
    );

    expect(container.read(stationsProvider).requireValue, hasLength(3));
    await pumpEventQueue();

    final after = container.read(stationsProvider);
    expect(_api.calls, 1);
    expect(after.hasError, isFalse);
    expect(after.requireValue, hasLength(3));
  });

  for (final (what, entry) in [
    ('unreadable', 'not json {'),
    ('in an old shape', '[{"id": "s1"}]'),
  ]) {
    test(
      'a stored entry that is $what is ignored, not shown as an error',
      () async {
        final container = await _setup(
          reply: () async => _reply(2),
          prefs: {_storedKey: entry},
        );

        expect(await container.read(stationsProvider.future), hasLength(2));
      },
    );
  }

  test('a stored list past its max age is dropped, so the screen waits for '
      'fresh data instead of showing a stale one', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ListCache(
      prefs,
      now: () =>
          DateTime.now().subtract(kCacheMaxAge + const Duration(days: 1)),
    ).write('/stations', [_station(1), _station(2)]);

    expect(ListCache(prefs).read('/stations'), isNull);

    final container = await _setupWith(prefs, reply: () async => _reply(4));
    final first = container.read(stationsProvider);
    expect(first.hasValue, isFalse, reason: 'no stale copy on screen');
    expect(await container.read(stationsProvider.future), hasLength(4));
    await pumpEventQueue();
    expect(_storedTop(container), hasLength(4), reason: 'and it is re-saved');
  });

  test(
    'a stored list just inside its max age is still shown at once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ListCache(
        prefs,
        now: () =>
            DateTime.now().subtract(kCacheMaxAge - const Duration(hours: 1)),
      ).write('/stations', [_station(1), _station(2)]);

      final container = await _setupWith(
        prefs,
        reply: () => Completer<dynamic>().future,
      );

      expect(container.read(stationsProvider).requireValue, hasLength(2));
    },
  );

  test('an unchanged list is only re-stamped about once a day', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var clock = DateTime(2026, 1, 1, 9);
    final cache = ListCache(prefs, now: () => clock);
    final items = [_station(1)];

    await cache.write('/stations', items);
    const stamp = 'list_cache.v1.stamp./stations';
    final first = prefs.getInt(stamp);

    clock = clock.add(const Duration(hours: 2));
    await cache.write('/stations', items);
    expect(prefs.getInt(stamp), first, reason: 'too soon, disk untouched');

    clock = clock.add(const Duration(days: 1));
    await cache.write('/stations', items);
    expect(prefs.getInt(stamp), isNot(first), reason: 'a day on, re-stamped');
  });

  test(
    'refresh() really fetches, rather than answering from the copy',
    () async {
      final container = await _setup(reply: () async => _reply(4), stored: 3);
      container.read(stationsProvider);
      await pumpEventQueue();
      expect(_api.calls, 1);

      await container.read(stationsProvider.notifier).refresh();

      expect(_api.calls, 2);
      expect(container.read(stationsProvider).requireValue, hasLength(4));
    },
  );

  test('a rebuild keeps the full list on screen rather than shrinking it to '
      'the stored top', () async {
    final container = await _setup(reply: () async => _reply(25));
    expect(await container.read(stationsProvider.future), hasLength(25));
    await pumpEventQueue();

    container.invalidate(stationsProvider);

    expect(container.read(stationsProvider).requireValue, hasLength(25));
  });
}
