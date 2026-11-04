import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/app.dart';
import 'package:e_radio/providers/connection_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/data/models/category.dart';
import 'package:e_radio/data/models/station.dart';
import 'package:e_radio/data/repositories/category_repository.dart';
import 'package:e_radio/providers/station_provider.dart';

import 'support/fake_connectivity.dart';

const _stations = [
  Station(
    id: '1',
    name: 'Test Station',
    streamUrl: 'https://example.com/stream.mp3',
  ),
];

const _categories = [Category(id: '1', name: 'News', slug: 'news')];

class _FakeStationsNotifier extends StationsNotifier {
  @override
  Future<List<Station>> build() async => _stations;
}

void main() {
  testWidgets('Explore screen renders the On Air stations carousel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          connectivitySourceProvider.overrideWithValue(
            FakeConnectivitySource(),
          ),
          stationsProvider.overrideWith(_FakeStationsNotifier.new),
          categoriesProvider.overrideWith((ref) async => _categories),
        ],
        child: const ERadioApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On Air'), findsOneWidget);
    expect(find.text('Test Station'), findsOneWidget);
    expect(find.text('• LIVE'), findsOneWidget);
    expect(find.text('Listen Radio'), findsOneWidget);
  });
}
