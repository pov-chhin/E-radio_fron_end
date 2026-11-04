import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/connection_provider.dart';
import '../../themes/theme_ext.dart';

/// "No Internet Connection": the page shown in place of content when the phone
/// has no internet. [onRetry] tries again — and, unless [retryWhenBack] is
/// false, is called by itself the moment the connection comes back, so nobody
/// has to tap. While [busy] the button shows that it is working and does
/// nothing.
///
/// Not for a server that can't be reached while the phone is online; that is
/// [NetworkErrorView]'s "Connection Lost".
class NoInternetView extends ConsumerWidget {
  const NoInternetView({
    super.key,
    required this.onRetry,
    this.busy = false,
    this.retryWhenBack = true,
  });

  final VoidCallback onRetry;
  final bool busy;
  final bool retryWhenBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(connectionStatusProvider, (previous, online) {
      if (retryWhenBack && online && previous == false) onRetry();
    });

    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: CustomPaint(
                size: const Size(
                  _NoSignalPainter.width * _iconScale,
                  _NoSignalPainter.height * _iconScale,
                ),
                painter: _NoSignalPainter(
                  // Lightest outside, darkest in — drawn from the page's own ink
                  // so it reads the same in a dark theme.
                  arcs: [
                    colors.onSurface.withValues(alpha: .28),
                    colors.onSurface.withValues(alpha: .38),
                    colors.onSurface.withValues(alpha: .48),
                  ],
                  dot: colors.onSurface.withValues(alpha: .85),
                ),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              l10n.noInternetTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 24,
                height: 32 / 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noInternetMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 16,
                height: 24 / 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Material(
              // Dark on a light page, light on a dark one.
              color: colors.onSurface,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: busy ? null : onRetry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 44,
                    vertical: 15,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The label keeps its room while the spinner replaces it,
                      // so the button does not change size.
                      Opacity(
                        opacity: busy ? 0 : 1,
                        child: Text(
                          l10n.tryAgain,
                          style: TextStyle(
                            color: colors.surface,
                            fontSize: 16,
                            height: 20 / 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (busy)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.surface,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The icon is drawn at design size, then scaled to fit the page.
  static const _iconScale = 0.72;
}

/// The Wi-Fi mark of the design: three arcs of growing darkness and, well below
/// them, a dot. Drawn in the design's own units ([width] × [height]) and scaled.
class _NoSignalPainter extends CustomPainter {
  const _NoSignalPainter({required this.arcs, required this.dot});

  static const width = 156.0;
  static const height = 172.0;

  final List<Color> arcs;
  final Color dot;

  static const _center = Offset(78, 112);
  static const _radii = [104.0, 74.0, 44.0];
  static const _stroke = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / width, size.height / height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    for (var i = 0; i < _radii.length; i++) {
      paint.color = arcs[i];
      canvas.drawArc(
        Rect.fromCircle(center: _center, radius: _radii[i]),
        -3 * math.pi / 4,
        math.pi / 2,
        false,
        paint,
      );
    }
    canvas.drawCircle(const Offset(78, 156), 14, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_NoSignalPainter old) =>
      old.arcs != arcs || old.dot != dot;
}
