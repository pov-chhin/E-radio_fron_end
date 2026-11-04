import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/repositories/media_content_repository.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/notifications_inbox_provider.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/screens/notifications/notifications_inbox_view.dart';
import 'package:e_radio/views/widgets/shared/network_thumbnail.dart';
import 'package:e_radio/views/widgets/shared/see_all_header.dart';
import 'support/fake_media_list.dart';

import 'support/test_fonts.dart';

MediaContent _release(
  String id,
  String title,
  DateTime at, {
  String artist = 'Chhin Pov',
}) => MediaContent(
  id: id,
  title: title,
  mediaType: 'song',
  artistName: artist,
  publishedAt: at,
);

late ProviderContainer _container;

Future<void> _pump(
  WidgetTester tester, {
  required List<MediaContent> releases,
  required DateTime seen,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    'notifications_seen_at': seen.toIso8601String(),
  });
  final prefs = await SharedPreferences.getInstance();

  _container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      newReleaseMediaContentsProvider.overrideWith(
        () => FakeMediaList(releases),
      ),
    ],
  );
  addTearDown(_container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (c, s) => const NotificationsInboxView(),
            ),
          ],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  final now = DateTime.now();
  final fresh = _release(
    '1',
    'Fresh Song',
    now.subtract(const Duration(minutes: 3)),
  );
  final old = _release(
    '2',
    'Old Song',
    now.subtract(const Duration(days: 3)),
    artist: 'Sok Dara',
  );
  final seen = now.subtract(const Duration(days: 2));

  testWidgets('puts what is new under Important and the rest under More', (
    tester,
  ) async {
    await _pump(tester, releases: [fresh, old], seen: seen);

    expect(find.text('Important'), findsOneWidget);
    expect(find.text('More notifications'), findsOneWidget);
    expect(find.text('Fresh Song'), findsOneWidget);
    expect(find.text('Old Song'), findsOneWidget);
    expect(find.text('3 minutes ago'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);
    expect(find.text('No notifications yet'), findsNothing);
  });

  testWidgets('only the new release has a blue dot', (tester) async {
    await _pump(tester, releases: [fresh, old], seen: seen);

    expect(find.byKey(const Key('unread-dot')), findsOneWidget);
  });

  testWidgets('opening it marks everything as seen', (tester) async {
    await _pump(tester, releases: [fresh, old], seen: seen);

    expect(_container.read(notificationsSeenProvider).isAfter(seen), isTrue);
  });

  testWidgets('mark all as read clears the dots and Important', (tester) async {
    await _pump(tester, releases: [fresh, old], seen: seen);

    await tester.tap(find.byTooltip('Mark all as read'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unread-dot')), findsNothing);
    expect(find.text('Important'), findsNothing);
    expect(find.text('Fresh Song'), findsOneWidget);
  });

  testWidgets('Hide this notification removes just that one', (tester) async {
    await _pump(tester, releases: [fresh, old], seen: seen);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide this notification'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh Song'), findsNothing);
    expect(find.text('Old Song'), findsOneWidget);
    expect(_container.read(notificationChoicesProvider).hidden, {'1'});
  });

  testWidgets('Show fewer keeps it, but never under Important', (tester) async {
    await _pump(tester, releases: [fresh, old], seen: seen);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show fewer from Chhin Pov'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh Song'), findsOneWidget);
    expect(find.text('Important'), findsNothing);
  });

  testWidgets('Turn off all from a source removes all of theirs', (
    tester,
  ) async {
    final second = _release(
      '3',
      'Second Song',
      now.subtract(const Duration(minutes: 9)),
    );
    await _pump(tester, releases: [fresh, second, old], seen: seen);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn off all from Chhin Pov'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh Song'), findsNothing);
    expect(find.text('Second Song'), findsNothing);
    expect(find.text('Old Song'), findsOneWidget);
  });

  testWidgets('lays a row out as drawn: 12px gaps, a 182px title column', (
    tester,
  ) async {
    await _pump(tester, releases: [fresh, old], seen: seen);

    // The page's bar is 52 tall (the See All pages' are 48).
    expect(tester.getSize(find.byType(SeeAllHeader)).height, 52);

    final title = find.ancestor(
      of: find.text('Fresh Song'),
      matching: find.byType(Column),
    );
    expect(tester.getSize(title.first).width, 182);

    // Picture 64 wide, 12 before the 24px ⋮ that ends 12 short of the edge.
    final picture = tester.getRect(find.byType(NetworkThumbnail).first);
    expect(picture.width, 64);
    expect(picture.left, 278);
    expect(
      tester.getRect(find.byIcon(Icons.more_vert_rounded).first).center.dx,
      366,
    );
    // The dots sit at the row's top, in line with the title's first line.
    expect(
      tester.getRect(find.byIcon(Icons.more_vert_rounded).first).top,
      closeTo(picture.top, 1),
    );
  });

  testWidgets('a row is 74 tall, and grows rather than overflows when the text '
      'is bigger', (tester) async {
    await _pump(tester, releases: [fresh, old], seen: seen);
    Finder row(String title) => find
        .ancestor(of: find.text(title), matching: find.byType(InkWell))
        .first;
    expect(tester.getSize(row('Fresh Song')).height, 86); // 74 + 12 padding

    const long = 'A long release title that is sure to need a second line';
    final longRelease = _release(
      '3',
      long,
      now.subtract(const Duration(minutes: 5)),
    );
    await _pump(
      tester,
      releases: [longRelease, old],
      seen: seen,
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(row(long)).height, greaterThan(86));
  });

  testWidgets('the source shows the artist photo, else their initials', (
    tester,
  ) async {
    final withPhoto = MediaContent(
      id: '9',
      title: 'Photo Song',
      mediaType: 'song',
      artistName: 'Sok Dara',
      artistPhotoUrl: 'https://example.com/dara.png',
      publishedAt: now.subtract(const Duration(days: 3)),
    );
    await _pump(tester, releases: [withPhoto, old], seen: seen);

    // Only the one with a photo draws a network picture (neither release has
    // a cover). Until it loads — here, never — the initials stand in, so they
    // show for both.
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.text('SD'), findsNWidgets(2));
  });

  test('unreadReleases counts what is new, minus hidden and muted', () {
    expect(unreadReleases(seen, [fresh, old]), 1);
    expect(unreadReleases(now, [fresh, old]), 0);
    expect(unreadReleases(seen, const []), 0);
    expect(
      unreadReleases(seen, [
        fresh,
        old,
      ], const NotificationChoices(hidden: {'1'})),
      0,
    );
    expect(
      unreadReleases(seen, [
        fresh,
        old,
      ], const NotificationChoices(muted: {'Chhin Pov'})),
      0,
    );
  });
}
