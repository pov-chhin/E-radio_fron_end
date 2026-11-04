import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../shared/eradio_logo_mark.dart';
import 'onboarding_choreography.dart';
import 'onboarding_dots.dart';
import 'onboarding_skip_button.dart';

/// The whole onboarding drawn at one moment of [timeline]: the gradient with
/// the splash logo, the light card sweeping about it with the badge on it, each
/// page's text, the dots, and — above all that, so they stay tappable — the
/// genre chips, the Continue / Let's Go! pill and Skip.
///
/// Mirrors the Figma frames "Onboarding 1…8". Their layouts are proportional to
/// the screen's height, as the app's other onboarding screens were.
class OnboardingScene extends StatelessWidget {
  const OnboardingScene({
    super.key,
    required this.timeline,
    required this.chips,
    required this.onSkip,
    required this.onContinue,
    required this.onFinish,
  });

  final OnboardingTimeline timeline;

  /// Passed in already built so the per-frame rebuild of the scene leaves it be.
  final Widget chips;

  final VoidCallback onSkip;
  final VoidCallback onContinue;
  final VoidCallback onFinish;

  /// Where the pages' headlines start, as a fraction of the height.
  static const _headlineTop = 0.715;

  /// The One Tap panel's visible height in the design, and the gap between it
  /// and its text above and the pill below.
  static const _panelBottom = 616.0;
  static const _panelPadding = 38.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final scale = Size(
          size.width / kOnboardingDesignSize.width,
          size.height / kOnboardingDesignSize.height,
        );
        return Stack(
          children: [
            // Look, don't touch: anything solid here would swallow the swipes
            // the pages underneath it are there to catch.
            Positioned.fill(
              child: IgnorePointer(child: _visuals(context, size, scale)),
            ),
            ..._controls(context, size, scale),
          ],
        );
      },
    );
  }

  Widget _visuals(BuildContext context, Size size, Size scale) {
    final l10n = AppLocalizations.of(context)!;
    final t = timeline;
    final tone = t.discoverTextTone;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.brandGradient),
          ),
        ),
        if (t.logoVisible)
          Center(
            child: Opacity(
              opacity: t.logoOpacity,
              child: Transform.scale(scale: t.logoScale, child: const _Logo()),
            ),
          ),
        _card(scale),
        if (t.discoverTextOpacity > 0)
          _headline(
            top: size.height * _headlineTop,
            opacity: t.discoverTextOpacity,
            title: l10n.onboardingDiscoverHeadline,
            subtitle: l10n.onboardingDiscoverSubtitle,
            titleStyle: TextStyle(
              color: Color.lerp(AppColors.lightInk, Colors.white, tone),
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
            subtitleStyle: TextStyle(
              color: Color.lerp(
                AppColors.lightInkSoft,
                Colors.white.withValues(alpha: 0.8),
                tone,
              ),
              fontSize: 14,
              height: 1.4,
            ),
            gap: 10,
          ),
        if (t.pickTextOpacity > 0)
          _headline(
            top: size.height * _headlineTop,
            opacity: t.pickTextOpacity,
            title: l10n.onboardingPickFavoritesHeadline,
            subtitle: l10n.onboardingPickFavoritesSubtitle,
            titleStyle: const TextStyle(
              color: AppColors.lightInk,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
            subtitleStyle: const TextStyle(
              color: AppColors.lightInkSoft,
              fontSize: 14,
              height: 1.4,
            ),
            gap: 8,
          ),
        if (t.oneTapTextOpacity > 0)
          _headline(
            bottom:
                size.height -
                _panelBottom * scale.height +
                _panelPadding -
                t.oneTapTextRise * scale.height,
            opacity: t.oneTapTextOpacity,
            title: l10n.onboardingOneTapHeadline,
            subtitle: l10n.onboardingOneTapSubtitle,
            titleStyle: const TextStyle(
              color: AppColors.lightInk,
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
            subtitleStyle: const TextStyle(
              color: AppColors.lightInkSoft,
              fontSize: 14,
              height: 1.4,
            ),
            gap: 8,
          ),
        if (t.dotsOpacity > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom:
                size.height * 0.10 -
                4 -
                (t.dotsDrop + t.dotsRise) * scale.height,
            child: Center(
              child: Opacity(
                opacity: t.dotsOpacity,
                child: OnboardingDots(
                  position: t.position,
                  lightness: t.dotsLightness,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The light card — and the logo badge riding on it. A rotated box rather
  /// than the old clip path so one shape can be every pose in between.
  Widget _card(Size scale) {
    final pose = timeline.card;
    final width = pose.size.width * scale.width;
    final height = pose.size.height * scale.height;
    final badge = timeline.badge;

    return Positioned(
      left: pose.center.dx * scale.width - width / 2,
      top: pose.center.dy * scale.height - height / 2,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: pose.rotation,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.pageBackground,
            borderRadius: BorderRadius.all(Radius.circular(40)),
          ),
          child: timeline.badgeOpacity <= 0
              ? null
              : Center(
                  child: Transform.translate(
                    offset: Offset(
                      badge.offset.dx * scale.width,
                      badge.offset.dy * scale.height,
                    ),
                    child: Transform.rotate(
                      angle: badge.rotation,
                      child: Opacity(
                        opacity: timeline.badgeOpacity,
                        child: const EradioLogoMark(size: 142),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// A page's title and subtitle, hung from [top] or standing on [bottom].
  Widget _headline({
    double? top,
    double? bottom,
    required double opacity,
    required String title,
    required String subtitle,
    required TextStyle titleStyle,
    required TextStyle subtitleStyle,
    required double gap,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: 28,
      right: 28,
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: titleStyle),
            SizedBox(height: gap),
            Text(subtitle, textAlign: TextAlign.center, style: subtitleStyle),
          ],
        ),
      ),
    );
  }

  List<Widget> _controls(BuildContext context, Size size, Size scale) {
    final t = timeline;
    // Faded out far enough to be gone is gone for taps too.
    bool tappable(double opacity) => opacity >= 0.6;

    return [
      if (t.chipsOpacity > 0)
        Positioned(
          left: 0,
          right: 0,
          top: 104 * scale.height,
          height: 474 * scale.height,
          child: IgnorePointer(
            ignoring: !tappable(t.chipsOpacity),
            child: Opacity(
              opacity: t.chipsOpacity,
              child: Transform.translate(
                offset: Offset(0, t.chipsRise * scale.height),
                child: chips,
              ),
            ),
          ),
        ),
      if (t.pillOpacity > 0)
        Positioned(
          left: 20,
          right: 20,
          top: t.pillTop * scale.height,
          child: IgnorePointer(
            ignoring: !tappable(t.pillOpacity),
            child: Opacity(
              opacity: t.pillOpacity,
              child: _ActionPill(
                morph: t.pillMorph,
                onTap: t.pillMorph < 0.5 ? onContinue : onFinish,
              ),
            ),
          ),
        ),
      if (t.skipOpacity > 0)
        Positioned.fill(
          child: SafeArea(
            child: IgnorePointer(
              ignoring: !tappable(t.skipOpacity),
              child: Opacity(
                opacity: t.skipOpacity,
                child: OnboardingSkipButton(onSkip: onSkip),
              ),
            ),
          ),
        ),
    ];
  }
}

/// The splash: the brand mark and wordmark, white on the gradient.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EradioLogoMark(size: 208, badge: false),
        SizedBox(height: 24),
        // The trailing letter-space would pull the word off-centre.
        Padding(
          padding: EdgeInsets.only(left: 9),
          child: Text(
            'E-RADIO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w300,
              letterSpacing: 9,
            ),
          ),
        ),
      ],
    );
  }
}

/// One pill that is "Continue" on the gradient at first and, as [morph] goes
/// to 1, turns into the light "Let's Go! →" pill (Figma 5 → 4).
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.morph, required this.onTap});

  final double morph;
  final VoidCallback onTap;

  static const _height = 60.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_height / 2),
      child: SizedBox(
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The light pill stays solid underneath while the gradient one
            // fades off it, so nothing behind shows through half-way.
            const ColoredBox(color: AppColors.pageBackground),
            Opacity(
              opacity: 1 - morph,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.brandButtonGradient,
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // One label out, then the other in, rather than both
                    // showing through each other half-way.
                    Opacity(
                      opacity: (1 - morph * 2).clamp(0.0, 1.0),
                      child: Center(
                        child: Text(
                          l10n.continueLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: (morph * 2 - 1).clamp(0.0, 1.0),
                      child: Row(
                        children: [
                          const SizedBox(width: 24),
                          Expanded(
                            child: Center(
                              child: Text(
                                l10n.letsGo,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
