import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

/// The bar at the top of a "See All" page: a back arrow on the left, the title
/// centred in 20/28 medium, and — when the page has one — a control on the
/// right. 48px tall (a page can ask for more), with the 20px page gutter.
class SeeAllHeader extends StatelessWidget {
  const SeeAllHeader({
    super.key,
    required this.title,
    this.trailing,
    this.height = 48,
  });

  final String title;

  /// The title is a 28px line; what is left of [height] is the padding above
  /// and below it.
  final double height;

  /// A 20–24px control for the right edge; the title stays centred without one.
  final Widget? trailing;

  static const _controlWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: (height - 28) / 2,
        ),
        child: Row(
          children: [
            InkResponse(
              radius: 24,
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/explore'),
              child: Semantics(
                button: true,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                excludeSemantics: true,
                child: SvgPicture.asset(
                  'assets/icons/arrow_left.svg',
                  width: 24,
                  height: 24,
                  // The artwork is drawn for the light theme.
                  colorFilter: theme.brightness == Brightness.dark
                      ? ColorFilter.mode(
                          theme.colorScheme.onSurface,
                          BlendMode.srcIn,
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  height: 28 / 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(
              width: _controlWidth,
              child: trailing == null ? null : Center(child: trailing),
            ),
          ],
        ),
      ),
    );
  }
}
