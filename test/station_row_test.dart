import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/data/models/station.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/views/widgets/shared/playing_indicator.dart';
import 'package:e_radio/views/widgets/shared/station_row.dart';

import 'support/test_fonts.dart';

const _station = Station(
  id: '1',
  name: 'Apsara FM97',
  streamUrl: 'https://example.com/live.m3u8',
  tags: ['News'],
);

class _FakePlayer extends AudioPlayerController {
  _FakePlayer(this._initial);
  final PlaybackState _initial;

  @override
  PlaybackState build() => _initial;
}

Future<void> _pump(WidgetTester tester, PlaybackState playback) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        audioPlayerControllerProvider.overrideWith(() => _FakePlayer(playback)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: StationRow(station: _station)),
      ),
    ),
  );
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('shows the equaliser mark next to the name while it plays', (
    tester,
  ) async {
    await _pump(
      tester,
      const PlaybackState(
        item: NowPlayingItem(
          id: 'station:1',
          title: 'Apsara FM97',
          streamUrl: 'https://example.com/live.m3u8',
          isLive: true,
        ),
        status: PlaybackStatus.playing,
      ),
    );

    expect(find.byType(PlayingIndicator), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Apsara FM97')).style?.color,
      Theme.of(tester.element(find.text('Apsara FM97'))).colorScheme.primary,
    );
  });

  testWidgets(
    'the ⋮ menu slides up over the bar the shell keeps at the bottom',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerControllerProvider.overrideWith(
              () => _FakePlayer(const PlaybackState()),
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              // The page lives in a navigator of its own with the bar outside
              // it, as each tab does in the app shell.
              body: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: StationRow(station: _station)),
                ),
              ),
              bottomNavigationBar: const SizedBox(key: Key('bar'), height: 120),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final bar = tester.getRect(find.byKey(const Key('bar')));
      final sheet = tester.getRect(find.byType(BottomSheet));
      // On the screen's own bottom edge, with the bar under it — not stopped at
      // the bar's top.
      expect(sheet.bottom, screenHeight);
      expect(sheet.bottom, greaterThan(bar.top));
    },
  );

  testWidgets('has no mark for a station that is not the one playing', (
    tester,
  ) async {
    await _pump(tester, const PlaybackState());

    expect(find.byType(PlayingIndicator), findsNothing);
  });

  testWidgets(
    'has no mark while the station is only loading, not yet playing',
    (tester) async {
      await _pump(
        tester,
        const PlaybackState(
          item: NowPlayingItem(
            id: 'station:1',
            title: 'Apsara FM97',
            streamUrl: 'https://example.com/live.m3u8',
            isLive: true,
          ),
          status: PlaybackStatus.loading,
        ),
      );

      expect(find.byType(PlayingIndicator), findsNothing);
    },
  );
}
