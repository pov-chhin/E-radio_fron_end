import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/models/now_playing_item.dart';
import 'package:e_radio/providers/audio_player_controller.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/widgets/explore/feed_card.dart';
import 'package:e_radio/views/widgets/shared/playing_indicator.dart';

/// Says what is loaded, and changes it on request.
class _Player extends AudioPlayerController {
  _Player([PlaybackState? initial])
    : _initial = initial ?? const PlaybackState();

  final PlaybackState _initial;

  @override
  PlaybackState build() => _initial;

  void show(PlaybackState next) => state = next;

  /// How often a tap asked to pause or resume.
  var toggles = 0;

  @override
  Future<void> togglePlayPause() async => toggles++;
}

const _story = MediaContent(
  id: '21',
  title: 'News Story One',
  mediaType: 'audio',
  categoryName: 'Reports',
  streamUrl: 'https://example.com/21.mp3',
);

const _other = MediaContent(
  id: '22',
  title: 'News Story Two',
  mediaType: 'audio',
  categoryName: 'Reports',
  streamUrl: 'https://example.com/22.mp3',
);

PlaybackState _state(MediaContent content, PlaybackStatus status) =>
    PlaybackState(
      item: NowPlayingItem.fromMediaContent(content),
      status: status,
    );

Future<_Player> _pump(
  WidgetTester tester, {
  PlaybackState? playback,
  MediaContent card = _story,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final player = _Player(playback);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        audioPlayerControllerProvider.overrideWith(() => player),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: FeedCard(item: card, queueItems: const [_story, _other]),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return player;
}

Finder get _mark => find.byKey(const Key('feedCardPlaying'));

/// The theme's primary colour, which is what the mark and the title use.
Color _primary(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(FeedCard))).colorScheme.primary;

TextStyle _titleStyle(WidgetTester tester) =>
    tester.widget<Text>(find.text('News Story One')).style!;

void main() {
  group('a card nothing is loaded for', () {
    testWidgets('has no mark and keeps its plain title', (tester) async {
      await _pump(tester);

      expect(_mark, findsNothing);
      expect(find.byType(PlayingIndicator), findsNothing);
      expect(_titleStyle(tester).fontWeight, FontWeight.w500);
      expect(_titleStyle(tester).color, isNot(_primary(tester)));
    });

    testWidgets('has no mark when something else is loaded', (tester) async {
      await _pump(tester, playback: _state(_other, PlaybackStatus.playing));

      expect(_mark, findsNothing);
      expect(find.byType(PlayingIndicator), findsNothing);
    });
  });

  group('the card of what is playing', () {
    testWidgets('is marked: a ring and dim over the picture, bars on it', (
      tester,
    ) async {
      await _pump(tester, playback: _state(_story, PlaybackStatus.playing));
      await tester.pumpAndSettle();

      expect(_mark, findsOneWidget);
      expect(
        find.descendant(of: _mark, matching: find.byType(PlayingIndicator)),
        findsOneWidget,
      );
      final decoration =
          tester.widget<DecoratedBox>(_mark).decoration as BoxDecoration;
      final ring = decoration.border! as Border;
      expect(ring.top.width, 2);
      expect(ring.top.color, _primary(tester));
      // Dimmed, so the bars show over any picture.
      expect(decoration.color!.a, greaterThan(0));
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('is exactly over the picture, 158 square', (tester) async {
      await _pump(tester, playback: _state(_story, PlaybackStatus.playing));
      await tester.pumpAndSettle();

      expect(tester.getSize(_mark), const Size(158, 158));
      expect(tester.getTopLeft(_mark), Offset.zero);
    });

    testWidgets('has its title in the brand colour and bolder', (tester) async {
      await _pump(tester, playback: _state(_story, PlaybackStatus.playing));

      expect(_titleStyle(tester).color, _primary(tester));
      expect(_titleStyle(tester).fontWeight, FontWeight.w600);
    });

    testWidgets('does not change the size of the card', (tester) async {
      await _pump(tester);
      final plain = tester.getSize(find.byType(FeedCard));

      await _pump(tester, playback: _state(_story, PlaybackStatus.playing));

      expect(tester.getSize(find.byType(FeedCard)), plain);
    });

    testWidgets('a tap on the marked picture still pauses or resumes it', (
      tester,
    ) async {
      final player = await _pump(
        tester,
        playback: _state(_story, PlaybackStatus.playing),
      );
      await tester.pumpAndSettle();

      // Right on the picture, where the mark lies: it takes no tap of its own.
      await tester.tapAt(tester.getCenter(_mark));
      await tester.pump();

      expect(player.toggles, 1);
    });
  });

  group('the card of what is paused or loading', () {
    testWidgets('paused: still marked, with a play button, not bars', (
      tester,
    ) async {
      await _pump(tester, playback: _state(_story, PlaybackStatus.paused));
      await tester.pumpAndSettle();

      expect(_mark, findsOneWidget);
      expect(find.byType(PlayingIndicator), findsNothing);
      expect(
        find.descendant(
          of: _mark,
          matching: find.byIcon(Icons.play_arrow_rounded),
        ),
        findsOneWidget,
      );
      expect(_titleStyle(tester).color, _primary(tester));
    });

    testWidgets('loading: marked, with a spinner', (tester) async {
      await _pump(tester, playback: _state(_story, PlaybackStatus.loading));
      await tester.pump(const Duration(milliseconds: 300));

      expect(_mark, findsOneWidget);
      expect(
        find.descendant(
          of: _mark,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.byType(PlayingIndicator), findsNothing);
    });
  });

  group('as playing changes', () {
    testWidgets('the mark appears when the card is picked, and goes when '
        'another is', (tester) async {
      final player = await _pump(tester);
      expect(_mark, findsNothing);

      player.show(_state(_story, PlaybackStatus.playing));
      await tester.pumpAndSettle();
      expect(_mark, findsOneWidget);

      player.show(_state(_other, PlaybackStatus.playing));
      await tester.pumpAndSettle();
      expect(_mark, findsNothing);
      expect(_titleStyle(tester).fontWeight, FontWeight.w500);
    });

    testWidgets('pausing swaps the bars for the play button, and back', (
      tester,
    ) async {
      final player = await _pump(
        tester,
        playback: _state(_story, PlaybackStatus.playing),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlayingIndicator), findsOneWidget);

      player.show(_state(_story, PlaybackStatus.paused));
      await tester.pumpAndSettle();
      expect(find.byType(PlayingIndicator), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      player.show(_state(_story, PlaybackStatus.playing));
      await tester.pumpAndSettle();
      expect(find.byType(PlayingIndicator), findsOneWidget);
    });

    testWidgets('it fades in rather than switching on at once', (tester) async {
      final player = await _pump(tester);

      player.show(_state(_story, PlaybackStatus.playing));
      await tester.pump(); // built, at the start of its fade
      await tester.pump(const Duration(milliseconds: 60));
      final partway = tester.widget<Opacity>(
        find.ancestor(of: _mark, matching: find.byType(Opacity)).first,
      );
      expect(partway.opacity, inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      final done = tester.widget<Opacity>(
        find.ancestor(of: _mark, matching: find.byType(Opacity)).first,
      );
      expect(done.opacity, 1);
    });
  });
}
