import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/onboarding_interests_provider.dart';
import 'interest_chip.dart';

/// The genre chips of "Pick Your Favorites". They scroll in their own area,
/// which fades out at the bottom above the headline.
class OnboardingChipsPanel extends ConsumerWidget {
  const OnboardingChipsPanel({super.key});

  static const _scrollTopPadding = 12.0;
  static const _scrollBottomPadding = 56.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingInterestsProvider);
    final notifier = ref.read(onboardingInterestsProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0, 0.86, 1],
        ).createShader(bounds),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            _scrollTopPadding,
            20,
            _scrollBottomPadding,
          ),
          // Centred when there's room to spare; on a shorter screen the rows
          // overflow and scroll, with the last one fading out.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight -
                  _scrollTopPadding -
                  _scrollBottomPadding,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in kOnboardingInterestRows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          for (final interest in row)
                            InterestChip(
                              interest: interest,
                              selected: selected.contains(interest.id),
                              onTap: () => notifier.toggle(interest.id),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
