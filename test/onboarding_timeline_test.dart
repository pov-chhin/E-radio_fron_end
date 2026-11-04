import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/views/widgets/onboarding/onboarding_choreography.dart';

/// The timeline is the Figma frames "Onboarding 1…8" read off as numbers, so
/// these pin it to the frames: at each page it must be the frame, and between
/// pages it must be going from one to the next.
void main() {
  group('the card', () {
    test('waits off the top-right while the splash is up', () {
      final card = const OnboardingTimeline(0).card;

      expect(card.center, OnboardingCardPose.aboveRight.center);
      // Entirely above the 844-tall screen.
      expect(card.center.dy + card.size.height / 2, lessThan(0));
    });

    test('covers the whole screen part-way to Discover', () {
      // 0.5–0.58 is the beat Figma holds on "Onboarding 7".
      final card = const OnboardingTimeline(0.54).card;

      expect(card.center, OnboardingCardPose.covering.center);
      expect(card.size, OnboardingCardPose.covering.size);
    });

    test('settles into the corner on Discover', () {
      final card = const OnboardingTimeline(1).card;

      expect(card.center, OnboardingCardPose.tilted.center);
      expect(card.size, OnboardingCardPose.tilted.size);
    });

    test('covers the screen again on Pick Your Favorites', () {
      final card = const OnboardingTimeline(2).card;

      expect(card.center, OnboardingCardPose.covering.center);
    });

    test('is the straight panel on One Tap to Play', () {
      final card = const OnboardingTimeline(3).card;

      expect(card.center, OnboardingCardPose.header.center);
      expect(card.rotation, 0);
      // Its visible part ends 616 down, as in "Onboarding 4".
      expect(card.center.dy + card.size.height / 2, 616);
    });

    test('holds its end poses when over-scrolled', () {
      expect(
        const OnboardingTimeline(-0.4).card.center,
        const OnboardingTimeline(0).card.center,
      );
      expect(
        const OnboardingTimeline(3.4).card.center,
        const OnboardingTimeline(3).card.center,
      );
    });
  });

  group('the splash logo', () {
    test('comes in with the intro and is gone by Discover', () {
      expect(const OnboardingTimeline(0, intro: 0).logoOpacity, 0);
      expect(const OnboardingTimeline(0, intro: 1).logoOpacity, 1);
      expect(const OnboardingTimeline(0.3).logoVisible, isFalse);
      expect(const OnboardingTimeline(1).logoOpacity, 0);
    });
  });

  group('the text', () {
    test('shows one page\'s at a time on the pages themselves', () {
      for (final (page, discover, pick, oneTap) in [
        (0.0, 0.0, 0.0, 0.0),
        (1.0, 1.0, 0.0, 0.0),
        (2.0, 0.0, 1.0, 0.0),
        (3.0, 0.0, 0.0, 1.0),
      ]) {
        final timeline = OnboardingTimeline(page);
        expect(timeline.discoverTextOpacity, discover, reason: 'page $page');
        expect(timeline.pickTextOpacity, pick, reason: 'page $page');
        expect(timeline.oneTapTextOpacity, oneTap, reason: 'page $page');
      }
    });

    test('turns from dark to white as the card moves off from behind it', () {
      expect(const OnboardingTimeline(0.5).discoverTextTone, 0);
      expect(const OnboardingTimeline(1).discoverTextTone, 1);
    });

    test('One Tap\'s rises into the panel', () {
      expect(const OnboardingTimeline(2.2).oneTapTextRise, 111);
      expect(const OnboardingTimeline(3).oneTapTextRise, 0);
    });
  });

  group('Continue / Let\'s Go!', () {
    test('Continue waits for a pick', () {
      expect(const OnboardingTimeline(2).pillOpacity, 0);
      expect(const OnboardingTimeline(2, continueIn: 1).pillOpacity, 1);
    });

    test('Let\'s Go! is there on the last page whatever was picked', () {
      final last = const OnboardingTimeline(3);

      expect(last.pillOpacity, 1);
      expect(last.pillMorph, 1);
      expect(last.pillTop, 653);
    });

    test('Continue sits at its Figma place once in', () {
      final pick = const OnboardingTimeline(2, continueIn: 1);

      expect(pick.pillMorph, 0);
      expect(pick.pillTop, 717);
    });

    test('is not there on Discover, picked or not', () {
      expect(const OnboardingTimeline(1, continueIn: 1).pillOpacity, 0);
    });
  });

  group('the dots', () {
    test('show from Discover on, with Continue taking their room', () {
      expect(const OnboardingTimeline(0).dotsOpacity, 0);
      expect(const OnboardingTimeline(1).dotsOpacity, 1);
      expect(const OnboardingTimeline(1).dotsDrop, 0);
      // 756 → 803 in Figma 3 → 5.
      expect(const OnboardingTimeline(2, continueIn: 1).dotsDrop, 47);
      expect(const OnboardingTimeline(3, continueIn: 1).dotsDrop, 0);
    });

    test('are white on the gradient and blue on the light page', () {
      expect(const OnboardingTimeline(1).dotsLightness, 0);
      expect(const OnboardingTimeline(2).dotsLightness, 1);
      expect(const OnboardingTimeline(3).dotsLightness, 0);
    });
  });

  group('the badge', () {
    test('rides the card, leaning one way swept in and the other settled', () {
      final swept = const OnboardingTimeline(0.54).badge;
      final settled = const OnboardingTimeline(1).badge;

      expect(swept.rotation, greaterThan(0));
      expect(settled.rotation, lessThan(0));
      expect(const OnboardingTimeline(0.54).badgeOpacity, 1);
    });

    test('is gone on Pick Your Favorites and back on One Tap to Play', () {
      expect(const OnboardingTimeline(2).badgeOpacity, 0);
      expect(const OnboardingTimeline(3).badgeOpacity, 1);
      expect(const OnboardingTimeline(3).badge.offset, const Offset(0, 80));
    });
  });
}
