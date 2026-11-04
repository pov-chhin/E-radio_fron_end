import 'package:flutter/material.dart';

/// The brand mark: a chunky rounded "E" beside a five-bar waveform. [badge]
/// shows the full logo — the rounded red→blue square with the "e" and the
/// "RADIO AMS" lettering — seen on light backgrounds (`e_radio_logo.png`, the
/// same artwork as the app icon); without it the mark is drawn in [markColor]
/// alone (used directly on the
/// gradient splash). [size] is the badge's edge either way, so the mark is
/// the same proportion of it in both forms.
class EradioLogoMark extends StatelessWidget {
  const EradioLogoMark({
    super.key,
    this.size = 96,
    this.badge = true,
    this.markColor = Colors.white,
  });

  final double size;
  final bool badge;
  final Color markColor;

  @override
  Widget build(BuildContext context) {
    final markHeight = size * 0.48;
    final mark = CustomPaint(
      size: Size(markHeight * _EradioMarkPainter.aspect, markHeight),
      painter: _EradioMarkPainter(markColor),
    );

    if (!badge) return mark;

    return Image.asset(
      'assets/images/auth/e_radio_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Everything is a fraction of the "E"'s height so the mark scales as a unit.
///
/// The E is one filled outline — three rounded-tip arms off a spine with a big
/// rounded outer edge — rather than strokes, so the slots between the arms get
/// the round inner ends the design has.
class _EradioMarkPainter extends CustomPainter {
  const _EradioMarkPainter(this.color);

  final Color color;

  static const _eWidth = 0.87;
  static const _armThickness = 0.22;
  static const _outerCornerRadius = 0.25;
  static const _middleArmInset = 0.10;

  static const _barWidth = 0.055;
  static const _barPitch = 0.088;
  static const _barStart = 0.827;
  static const _barHeights = [0.14, 0.28, 0.46, 0.28, 0.14];

  /// Width ÷ height of the whole mark (E plus waveform).
  static const aspect = _barStart + 4 * _barPitch + _barWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final s = _armThickness * h; // arm thickness
    final g = (h - 3 * s) / 2; // gap between arms
    final w = _eWidth * h;
    final middleTip = w - _middleArmInset * h;
    final r = _outerCornerRadius * h;
    final tip = s / 2;
    final slotEnd = s + g / 2; // x of the centre of each slot's rounded end

    // Clockwise from the top-left, so the slots (concave) are the
    // counter-clockwise arcs.
    final e = Path()
      ..moveTo(r, 0)
      ..lineTo(w - tip, 0)
      ..arcToPoint(Offset(w - tip, s), radius: Radius.circular(tip))
      ..lineTo(slotEnd, s)
      ..arcToPoint(
        Offset(slotEnd, s + g),
        radius: Radius.circular(g / 2),
        clockwise: false,
      )
      ..lineTo(middleTip - tip, s + g)
      ..arcToPoint(
        Offset(middleTip - tip, 2 * s + g),
        radius: Radius.circular(tip),
      )
      ..lineTo(slotEnd, 2 * s + g)
      ..arcToPoint(
        Offset(slotEnd, 2 * s + 2 * g),
        radius: Radius.circular(g / 2),
        clockwise: false,
      )
      ..lineTo(w - tip, 2 * s + 2 * g)
      ..arcToPoint(Offset(w - tip, h), radius: Radius.circular(tip))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(e, paint);

    for (var i = 0; i < _barHeights.length; i++) {
      final barHeight = _barHeights[i] * h;
      final x = _barStart * h + i * _barPitch * h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (h - barHeight) / 2, _barWidth * h, barHeight),
          Radius.circular(_barWidth * h / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EradioMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
