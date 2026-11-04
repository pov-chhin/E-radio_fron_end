import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/models/tag.dart';
import 'package:e_radio/data/repositories/category_repository.dart';
import 'package:e_radio/data/repositories/media_content_repository.dart';
import 'package:e_radio/data/repositories/tag_repository.dart';
import 'package:e_radio/data/services/api_client.dart';
import 'package:e_radio/data/services/api_exception.dart';
import 'package:e_radio/l10n/gen/app_localizations.dart';
import 'package:e_radio/providers/shared_preferences_provider.dart';
import 'package:e_radio/views/screens/category/category_view.dart';

import 'support/test_fonts.dart';

const _topics = [
  Tag(
    id: '1',
    name: 'News',
    slug: 'news',
    children: [
      Tag(id: '7', name: 'Local', slug: 'local'),
      Tag(id: '8', name: 'World', slug: 'world'),
    ],
  ),
];

List<MediaContent> _items(int from, int to) => [
  for (var i = from; i <= to; i++)
    MediaContent(id: '$i', title: 'Story $i', mediaType: 'video'),
];

Map<String, dynamic> _page(int from, int to) => {
  'data': [
    for (var i = from; i <= to; i++)
      {'id': '$i', 'title': 'Story $i', 'media_type': 'video'},
  ],
};

/// Answers the later pages from [reply], and remembers what it was asked.
class _PagesApi extends ApiClient {
  _PagesApi(this.reply);

  final Future<dynamic> Function(String path) reply;
  final paths = <String>[];

  @override
  Future<dynamic> get(String path, {String? token}) {
    paths.add(path);
    return reply(path);
  }
}

Future<void> _pump(
  WidgetTester tester,
  _PagesApi api, {
  List<MediaContent>? all,
  List<MediaContent> local = const [],
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const CategoryView(categorySlug: 'news'),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
        tagsProvider.overrideWith((ref) async => _topics),
        categoriesProvider.overrideWith((ref) async => const []),
        mediaContentsByCategoryProvider.overrideWith(
          (ref, slug) async => all ?? _items(1, 3),
        ),
        mediaContentsByTagProvider.overrideWith(
          (ref, tagId) async => tagId == '7' ? local : const [],
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  final list = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.drag(list, const Offset(0, -1500));
      await tester.pump();
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  group('A category page', () {
    testWidgets('a short list has nothing more to ask for', (tester) async {
      final api = _PagesApi((path) async => _page(21, 25));
      await _pump(tester, api);
      await scrollToEnd(tester);

      expect(find.text('Story 3'), findsOneWidget);
      expect(api.paths, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('loads the next 20 at the end, and stops after the last', (
      tester,
    ) async {
      final api = _PagesApi((path) async => _page(21, 25));
      await _pump(tester, api, all: _items(1, 20));
      expect(api.paths, isEmpty);

      await scrollToEnd(tester);

      expect(api.paths, ['/media-contents?category=news&page=2']);
      expect(find.text('Story 25'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('keeps asking while the pages come back full', (tester) async {
      final api = _PagesApi(
        (path) async => path.endsWith('page=2') ? _page(21, 40) : _page(41, 43),
      );
      await _pump(tester, api, all: _items(1, 20));

      await scrollToEnd(tester);
      await scrollToEnd(tester);

      expect(api.paths, [
        '/media-contents?category=news&page=2',
        '/media-contents?category=news&page=3',
      ]);
      expect(find.text('Story 43'), findsOneWidget);
    });

    testWidgets('a topic tab pages through its own content', (tester) async {
      final api = _PagesApi((path) async => _page(121, 123));
      await _pump(tester, api, local: _items(101, 120));

      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      expect(find.text('Story 101'), findsOneWidget);

      await scrollToEnd(tester);

      expect(api.paths, ['/media-contents?tag_id=7&page=2']);
      expect(find.text('Story 123'), findsOneWidget);
    });

    testWidgets('swiping sideways moves to the next tab', (tester) async {
      final api = _PagesApi((path) async => _page(21, 25));
      await _pump(tester, api, local: _items(101, 102));

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Story 101'), findsOneWidget);
      expect(find.text('Story 1'), findsNothing);
    });

    testWidgets('a failed page offers Retry, which loads it', (tester) async {
      var fail = true;
      final api = _PagesApi((path) async {
        if (fail) throw ApiException('down', statusCode: 500);
        return _page(21, 25);
      });
      await _pump(tester, api, all: _items(1, 20));

      await scrollToEnd(tester);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Story 20'), findsOneWidget);
      expect(api.paths, hasLength(1)); // it did not hammer the API

      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await scrollToEnd(tester);

      expect(find.text('Retry'), findsNothing);
      expect(find.text('Story 25'), findsOneWidget);
    });
  });
}
