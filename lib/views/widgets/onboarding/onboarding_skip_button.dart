import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';

/// "Skip" in the top-right corner of the pages that sit on the light
/// background.
class OnboardingSkipButton extends StatelessWidget {
  const OnboardingSkipButton({super.key, required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 12, 0),
        child: TextButton(
          onPressed: onSkip,
          child: Text(
            l10n.onboardingSkip,
            style: const TextStyle(
              color: AppColors.lightInk,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
