import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/views/widgets/shared/dots_menu.dart';

/// The ⋮ popup ("Show Dots PopUp" in the design).
void main() {
  var picked = <String>[];

  Future<void> pumpMenu(
    WidgetTester tester, {
    Alignment alignment = Alignment.topRight,
    double inset = 100,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    picked = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: alignment,
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, inset, 20, inset),
              child: Builder(
                builder: (buttonContext) => IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () => showDotsMenu(buttonContext, [
                    DotsMenuItem(
                      icon: Icons.visibility_off_outlined,
                      label: 'Hide it',
                      onTap: () => picked.add('hide'),
                    ),
                    DotsMenuItem(
                      label: 'Show fewer',
                      onTap: () => picked.add('fewer'),
                    ),
                    DotsMenuItem(
                      icon: Icons.notifications_off_outlined,
                      label: 'Turn off',
                      onTap: () => picked.add('off'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder card() => find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).borderRadius ==
            BorderRadius.circular(12),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'opens a card under the dots with its right edge just past them',
    (tester) async {
      await pumpMenu(tester);
      final dots = tester.getCenter(find.byIcon(Icons.more_vert_rounded));
      await open(tester);

      final rect = tester.getRect(card());
      expect(rect.top, closeTo(dots.dy + 22, 0.5));
      expect(rect.right, closeTo(dots.dx + 4, 0.5));
      // 10 above, three 22px lines with 16 between, 10 below.
      expect(rect.height, closeTo(118, 0.5));
      expect(find.text('Hide it'), findsOneWidget);
      expect(find.text('Show fewer'), findsOneWidget);
      expect(find.text('Turn off'), findsOneWidget);
    },
  );

  testWidgets('a line without an icon keeps the icon\'s room', (tester) async {
    await pumpMenu(tester);
    await open(tester);

    expect(
      tester.getTopLeft(find.text('Show fewer')).dx,
      tester.getTopLeft(find.text('Hide it')).dx,
    );
  });

  testWidgets('flips above the dots when there is no room below', (
    tester,
  ) async {
    await pumpMenu(tester, alignment: Alignment.bottomRight, inset: 20);
    final dots = tester.getCenter(find.byIcon(Icons.more_vert_rounded));
    await open(tester);

    expect(tester.getRect(card()).bottom, closeTo(dots.dy - 22, 0.5));
  });

  testWidgets('dims the page faintly behind it', (tester) async {
    await pumpMenu(tester);
    await open(tester);

    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, const Color(0x0A000000));
  });

  testWidgets('picking a line closes the popup and does that', (tester) async {
    await pumpMenu(tester);
    await open(tester);

    await tester.tap(find.text('Show fewer'));
    await tester.pumpAndSettle();

    expect(picked, ['fewer']);
    expect(find.text('Show fewer'), findsNothing);
  });

  testWidgets('a tap outside closes it without doing anything', (tester) async {
    await pumpMenu(tester);
    await open(tester);

    await tester.tapAt(const Offset(40, 500));
    await tester.pumpAndSettle();

    expect(picked, isEmpty);
    expect(find.text('Hide it'), findsNothing);
  });
}
