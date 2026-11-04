import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/animation.dart';

/// The size the Figma onboarding frames are drawn at. Every pose below is in
/// these units; the scene scales them to the real screen.
const kOnboardingDesignSize = Size(390, 844);

/// How far the intro runs — the splash is position 0, "One Tap to Play" is 3.
const kOnboardingLastPosition = 3.0;

const _tilt = -4 * math.pi / 180;

/// Where the light card is, in design units from the screen's top-left.
class OnboardingCardPose {
  const OnboardingCardPose({
    required this.center,
    required this.size,
    required this.rotation,
  });

  final Offset center;
  final Size size;
  final double rotation;

  /// "Onboarding 2": waiting off the top-right corner.
  static const aboveRight = OnboardingCardPose(
    center: Offset(661.4, -420),
    size: Size(600, 800),
    rotation: _tilt,
  );

  /// "Onboarding 7": swept across, covering the whole screen. It is also what
  /// "Pick Your Favorites" sits on — Figma draws that page as a plain light
  /// background, which this pose is indistinguishable from.
  static const covering = OnboardingCardPose(
    center: Offset(261, 374.6),
    size: Size(600, 970),
    rotation: _tilt,
  );

  /// "Onboarding 6": settled in the upper left, its lower-left corner showing.
  static const tilted = OnboardingCardPose(
    center: Offset(306.25, 142),
    size: Size(600, 800),
    rotation: _tilt,
  );

  /// "Onboarding 4": a straight panel hanging from the top, 616 tall with
  /// rounded bottom corners. Drawn 160 taller than that, the extra bleeding off
  /// the top, so its top corners never show while it grows into place.
  static const header = OnboardingCardPose(
    center: Offset(195, 228),
    size: Size(390, 776),
    rotation: 0,
  );

  static OnboardingCardPose lerp(
    OnboardingCardPose a,
    OnboardingCardPose b,
    double t,
  ) => OnboardingCardPose(
    center: Offset.lerp(a.center, b.center, t)!,
    size: Size.lerp(a.size, b.size, t)!,
    rotation: lerpDouble(a.rotation, b.rotation, t)!,
  );
}

/// The logo badge's place inside the card: its offset from the card's centre
/// and its own tilt, on top of the card's.
class OnboardingBadgePose {
  const OnboardingBadgePose({required this.offset, required this.rotation});

  final Offset offset;
  final double rotation;

  /// "Onboarding 7": left of centre, leaning the other way to the card.
  static const swept = OnboardingBadgePose(
    offset: Offset(-64.55, -23.16),
    rotation: 10 * math.pi / 180,
  );

  /// "Onboarding 6": low in the card, so it lands on the Discover page's
  /// upper-middle once the card has moved up.
  static const settled = OnboardingBadgePose(
    offset: Offset(-113.81, 172.31),
    rotation: -2 * math.pi / 180,
  );

  /// "Onboarding 4": centred in the panel's visible 616.
  static const header = OnboardingBadgePose(offset: Offset(0, 80), rotation: 0);

  static OnboardingBadgePose lerp(
    OnboardingBadgePose a,
    OnboardingBadgePose b,
    double t,
  ) => OnboardingBadgePose(
    offset: Offset.lerp(a.offset, b.offset, t)!,
    rotation: lerpDouble(a.rotation, b.rotation, t)!,
  );
}

/// Eases [position] through the [from]…[to] stretch: 0 before it, 1 after it.
double _ramp(
  double position,
  double from,
  double to, [
  Curve curve = Curves.easeInOutCubic,
]) => curve.transform(((position - from) / (to - from)).clamp(0.0, 1.0));

/// Everything that moves in the onboarding, as a function of one number.
///
/// Figma draws the intro as eight frames joined by Smart Animate rather than
/// as keyframes, so this is read off the frames. [position] is the page —
/// 0 splash, 1 Discover, 2 Pick Your Favorites, 3 One Tap to Play — and the
/// stretch between two whole numbers is the transition between them. Because
/// it is only a function of [position], a swipe scrubs it and swiping back
/// plays it in reverse.
///
/// Each stretch runs through the frames Figma has for it:
///  * 0 → 1: the logo (8) goes, the card waits off the top-right (2), sweeps
///    across to cover the screen with the badge and headline on it (7), then
///    settles into the corner (6) as the headline turns white.
///  * 1 → 2: the card sweeps back over the screen (7) and "Pick Your
///    Favorites" (3) appears on it.
///  * 2 → 3: the card shrinks to the panel at the top (4), the badge arrives
///    in it and "Continue" becomes "Let's Go!".
class OnboardingTimeline {
  const OnboardingTimeline(
    this.position, {
    this.intro = 1,
    this.continueIn = 0,
  });

  /// The page, 0…3 (clamped — an over-scroll holds the end poses).
  final double position;

  /// 0…1: the logo coming in when the intro opens (Figma 1 → 8).
  final double intro;

  /// 0…1: how far "Continue" has come in after a genre is picked (Figma
  /// 3 → 5). Zero while nothing is picked.
  final double continueIn;

  double get _p => position.clamp(0.0, kOnboardingLastPosition);

  // --- The card -------------------------------------------------------------

  OnboardingCardPose get card {
    final p = _p;
    if (p <= 1) {
      final sweptIn = OnboardingCardPose.lerp(
        OnboardingCardPose.aboveRight,
        OnboardingCardPose.covering,
        _ramp(p, 0.10, 0.50, Curves.easeOutCubic),
      );
      // A short hold at "Onboarding 7" before it settles.
      return OnboardingCardPose.lerp(
        sweptIn,
        OnboardingCardPose.tilted,
        _ramp(p, 0.58, 1.0),
      );
    }
    if (p <= 2) {
      return OnboardingCardPose.lerp(
        OnboardingCardPose.tilted,
        OnboardingCardPose.covering,
        _ramp(p, 1.0, 1.45),
      );
    }
    return OnboardingCardPose.lerp(
      OnboardingCardPose.covering,
      OnboardingCardPose.header,
      _ramp(p, 2.0, 2.55),
    );
  }

  OnboardingBadgePose get badge {
    final p = _p;
    if (p <= 1) {
      return OnboardingBadgePose.lerp(
        OnboardingBadgePose.swept,
        OnboardingBadgePose.settled,
        _ramp(p, 0.58, 1.0),
      );
    }
    // Hidden while the card moves in between, so the jump is never seen.
    return p <= 2 ? OnboardingBadgePose.settled : OnboardingBadgePose.header;
  }

  double get badgeOpacity {
    final p = _p;
    if (p <= 1) return 1;
    if (p <= 2) return 1 - _ramp(p, 1.0, 1.2);
    return _ramp(p, 2.5, 2.8);
  }

  // --- The splash logo -------------------------------------------------------

  bool get logoVisible => _p < 0.18;

  double get logoOpacity =>
      Curves.easeOut.transform(intro) * (1 - _ramp(_p, 0, 0.16));

  double get logoScale =>
      lerpDouble(0.92, 1, Curves.easeOutCubic.transform(intro))! *
      (1 - 0.05 * _ramp(_p, 0, 0.16));

  // --- Text -----------------------------------------------------------------

  /// "Discover Live Radio": appears on the card once it has swept in, dark on
  /// the card, then white as the card moves off from behind it.
  double get discoverTextOpacity =>
      _ramp(_p, 0.30, 0.46) * (1 - _ramp(_p, 1.0, 1.2));

  /// 0 = dark ink (on the card), 1 = white (on the gradient). The change is
  /// timed for the moment the card's lower edge passes up through the text, so
  /// it is not left half one colour for long.
  double get discoverTextTone => _ramp(_p, 0.76, 0.92);

  double get pickTextOpacity =>
      _ramp(_p, 1.5, 1.85) * (1 - _ramp(_p, 2.0, 2.3));

  double get oneTapTextOpacity => _ramp(_p, 2.35, 2.75);

  /// Design units the "One Tap to Play" text still has to climb: it starts
  /// where the other pages' text sits and rises into the panel (Figma 5 → 4).
  double get oneTapTextRise => 111 * (1 - _ramp(_p, 2.2, 2.75));

  // --- The genre chips --------------------------------------------------------

  double get chipsOpacity => _ramp(_p, 1.55, 1.9) * (1 - _ramp(_p, 2.0, 2.25));

  double get chipsRise => 18 * (1 - _ramp(_p, 1.55, 1.9));

  // --- Skip, dots -------------------------------------------------------------

  double get skipOpacity => _ramp(_p, 0.88, 1.0) * (1 - _ramp(_p, 2.0, 2.3));

  double get dotsOpacity => _ramp(_p, 0.82, 1.0);

  /// Design units the dots still have to rise into place when they first show.
  double get dotsRise => 24 * (1 - _ramp(_p, 0.82, 1.0));

  /// 0 = white dots (on the gradient), 1 = blue/grey dots (on the light page).
  double get dotsLightness => _ramp(_p, 1.15, 1.5) * (1 - _ramp(_p, 2.3, 2.7));

  /// Design units the dots drop to make room for the Continue button coming
  /// in (Figma 3 → 5: from y 756 to 803).
  double get dotsDrop =>
      47 * continueIn * _ramp(_p, 1.5, 1.9) * (1 - _ramp(_p, 2.0, 2.6));

  // --- The Continue / Let's Go! button ---------------------------------------

  /// 0 = "Continue" on the gradient pill, 1 = "Let's Go!" on the light one.
  double get pillMorph => _ramp(_p, 2.1, 2.6);

  /// "Continue" is only there once a genre is picked; "Let's Go!" always is.
  double get pillOpacity {
    final continueShown = continueIn * _ramp(_p, 1.6, 1.95);
    return lerpDouble(continueShown, 1, pillMorph)!;
  }

  /// Top edge in design units — 717 for Continue, 653 for Let's Go!.
  double get pillTop {
    final rise = 24 * (1 - continueIn) * (1 - pillMorph);
    return lerpDouble(717, 653, pillMorph)! + rise;
  }
}
