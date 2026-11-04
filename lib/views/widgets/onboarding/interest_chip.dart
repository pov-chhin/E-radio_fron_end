import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';

class OnboardingInterest {
  const OnboardingInterest(this.id, this.label, this.icon, this.color);

  final String id;
  final String Function(AppLocalizations) label;
  final IconData icon;
  final Color color;
}

/// The genres offered on "Pick Your Favorites", in the design's order. The ids
/// are what gets persisted, so they must not change.
final kOnboardingInterests = <OnboardingInterest>[
  OnboardingInterest(
    'news_talk',
    (l10n) => l10n.interestNewsTalk,
    Icons.newspaper_rounded,
    const Color(0xFFEF5350),
  ),
  OnboardingInterest(
    'education',
    (l10n) => l10n.interestEducation,
    Icons.school_outlined,
    const Color(0xFF29A3F5),
  ),
  OnboardingInterest(
    'sports',
    (l10n) => l10n.interestSports,
    Icons.fitness_center_rounded,
    const Color(0xFFFF9F43),
  ),
  OnboardingInterest(
    'music',
    (l10n) => l10n.interestMusic,
    Icons.music_note_outlined,
    AppColors.brand400,
  ),
  OnboardingInterest(
    'economy',
    (l10n) => l10n.interestEconomy,
    Icons.assignment_outlined,
    const Color(0xFFA98467),
  ),
  OnboardingInterest(
    'infotainment',
    (l10n) => l10n.interestInfotainment,
    Icons.sentiment_satisfied_alt_outlined,
    const Color(0xFFF4C430),
  ),
  OnboardingInterest(
    'lifestyle',
    (l10n) => l10n.interestLifestyle,
    Icons.local_cafe_outlined,
    const Color(0xFF22C3E6),
  ),
  OnboardingInterest(
    'radio',
    (l10n) => l10n.interestRadio,
    Icons.radio_outlined,
    const Color(0xFF9333EA),
  ),
  OnboardingInterest(
    'ams_programs',
    (l10n) => l10n.interestAmsPrograms,
    Icons.hub_outlined,
    const Color(0xFF4DA3FF),
  ),
  OnboardingInterest(
    'culture',
    (l10n) => l10n.interestCulture,
    Icons.public_outlined,
    const Color(0xFFB91C1C),
  ),
  OnboardingInterest(
    'relaxation',
    (l10n) => l10n.interestRelaxation,
    Icons.spa_outlined,
    const Color(0xFF4ADE80),
  ),
  OnboardingInterest(
    'ambient',
    (l10n) => l10n.interestAmbient,
    Icons.audiotrack_outlined,
    const Color(0xFFA78BFA),
  ),
  OnboardingInterest(
    'trends',
    (l10n) => l10n.interestTrends,
    Icons.local_fire_department_outlined,
    const Color(0xFFF04438),
  ),
  OnboardingInterest(
    'business',
    (l10n) => l10n.interestBusiness,
    Icons.account_balance_wallet_outlined,
    const Color(0xFF7C6FDC),
  ),
];

/// The design lays the chips out in fixed, centred rows — 2, 2, 1, 2, 1, 2, 1,
/// 2, 1 — rather than letting them auto-wrap, so the arrangement is the same on
/// every screen width. Each row still wraps if a screen is too narrow for it.
final kOnboardingInterestRows = [
  for (final ids in const [
    ['news_talk', 'education'],
    ['sports', 'music'],
    ['economy'],
    ['infotainment', 'lifestyle'],
    ['radio'],
    ['ams_programs', 'culture'],
    ['relaxation'],
    ['ambient', 'trends'],
    ['business'],
  ])
    [
      for (final id in ids)
        kOnboardingInterests.firstWhere((interest) => interest.id == id),
    ],
];

/// A pill for one genre: its coloured icon and name, turning solid blue with a
/// check mark when picked.
class InterestChip extends StatelessWidget {
  const InterestChip({
    super.key,
    required this.interest,
    required this.selected,
    required this.onTap,
  });

  final OnboardingInterest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const shape = StadiumBorder();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: ShapeDecoration(
        color: selected ? AppColors.brandBlue : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.brandBlue : AppColors.chipBorder,
          ),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 16, 0),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? Icons.check_rounded : interest.icon,
                    size: 20,
                    color: selected ? Colors.white : interest.color,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    interest.label(l10n),
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
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
