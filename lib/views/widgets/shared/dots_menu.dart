import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../themes/theme_ext.dart';

/// One line of a [showDotsMenu] popup: an optional 16px icon — a Material
/// [icon], or a drawn one from [asset] (a 16px SVG, dark artwork that is
/// re-inked on the dark theme) — the [label], and what happens when it is
/// picked (after the popup has closed).
class DotsMenuItem {
  const DotsMenuItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.asset,
  });

  final String label;
  final VoidCallback onTap;

  /// A line with neither icon still keeps their room, so the labels line up.
  final IconData? icon;
  final String? asset;
}

/// The ⋮ options as the design's "Show Dots PopUp": a small white card that
/// opens beside the button — right edge just past the dots, a little below
/// them, flipping above when there's no room — over a faint dimming of the
/// page. [context] must be the ⋮ button's own (use a Builder), it's where the
/// card is anchored. A tap outside closes it.
Future<void> showDotsMenu(BuildContext context, List<DotsMenuItem> items) {
  final box = context.findRenderObject()! as RenderBox;
  final anchor = box.localToGlobal(box.size.center(Offset.zero));

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x0A000000),
    transitionDuration: const Duration(milliseconds: 120),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        CustomSingleChildLayout(
          delegate: _DotsMenuLayout(
            anchor: anchor,
            safe: MediaQuery.paddingOf(dialogContext),
          ),
          child: _DotsMenuCard(items: items),
        ),
  );
}

/// Puts the card by the ⋮ — see [showDotsMenu].
class _DotsMenuLayout extends SingleChildLayoutDelegate {
  const _DotsMenuLayout({required this.anchor, required this.safe});

  /// The middle of the ⋮ button, in the dialog's own coordinates.
  final Offset anchor;
  final EdgeInsets safe;

  /// How far past the ⋮'s middle the card's right edge reaches, and how far
  /// below it the card starts (the 24px icon's half-height plus 10).
  static const _past = 4.0;
  static const _below = 22.0;
  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth - 2 * _margin);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = math.max(_margin, size.width - childSize.width - _margin);
    final left = (anchor.dx + _past - childSize.width).clamp(_margin, maxLeft);

    final bottomEdge = size.height - safe.bottom - _margin;
    var top = anchor.dy + _below;
    if (top + childSize.height > bottomEdge) {
      top = anchor.dy - _below - childSize.height;
    }
    final minTop = safe.top + _margin;
    final maxTop = math.max(minTop, bottomEdge - childSize.height);
    return Offset(left.toDouble(), top.clamp(minTop, maxTop).toDouble());
  }

  @override
  bool shouldRelayout(_DotsMenuLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.safe != safe;
}

/// White, 12px corners, a hairline of shadow; lines 14/22 with 16px between
/// them, 16px in from the sides and 10px from the top and bottom.
class _DotsMenuCard extends StatelessWidget {
  const _DotsMenuCard({required this.items});

  final List<DotsMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.raisedCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          // Each line carries 8px above and below itself, so the 16px between
          // two lines and the 10px at the ends add up with these 2px.
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in items)
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      item.onTap();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: item.asset != null
                                ? Center(
                                    child: SvgPicture.asset(
                                      item.asset!,
                                      colorFilter:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? ColorFilter.mode(
                                              colors.onSurface,
                                              BlendMode.srcIn,
                                            )
                                          : null,
                                    ),
                                  )
                                : item.icon == null
                                ? null
                                : Icon(
                                    item.icon,
                                    size: 16,
                                    color: colors.onSurface,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 14,
                                height: 22 / 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
