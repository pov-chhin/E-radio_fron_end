import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';

/// Page dots for the onboarding flow. The splash counts as the first page, so
/// the three content pages show dot 1, 2 and 3 of [total].
///
/// [position] is a fractional page, so while the pages are in transition the
/// active dot hands over to the next: one stretches out as the other draws
/// in, in step with a swipe.
class OnboardingDots extends StatelessWidget {
  const OnboardingDots({
    super.key,
    required this.position,
    this.total = 4,
    this.lightness = 0,
  });

  final double position;
  final int total;

  /// 0 = white dots, for the gradient pages; 1 = blue/grey dots, for the light
  /// ones. In between while the page behind them changes.
  final double lightness;

  @override
  Widget build(BuildContext context) {
    final activeColor = Color.lerp(
      Colors.white,
      AppColors.brandBlue,
      lightness,
    )!;
    final inactiveColor = Color.lerp(
      Colors.white.withValues(alpha: 0.3),
      AppColors.dotInactiveLight,
      lightness,
    )!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          _dot(
            math.max(0.0, 1 - (position - i).abs()),
            activeColor,
            inactiveColor,
          ),
      ],
    );
  }

  /// [activeness] is 1 for the dot the pages are on and 0 for one a whole page
  /// or more away.
  Widget _dot(double activeness, Color active, Color inactive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 8 + 16 * activeness,
      height: 8,
      decoration: BoxDecoration(
        color: Color.lerp(inactive, active, activeness),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
