import 'package:flutter/material.dart';

/// Brand tokens matched to the e-Radio reference site (e-radio-seven.vercel.app),
/// pulled from its public theme-color meta tag and Tailwind CSS variables.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF6A6CF1);
  static const brand400 = Color(0xFF8B5CF6);
  static const brand600 = Color(0xFF6366F1);
  static const brandBlue = Color(0xFF3B82F6);

  /// Light page background and hairlines used by the onboarding screens.
  static const pageBackground = Color(0xFFF8FAFC);
  static const chipBorder = Color(0xFFE8EAF0);
  static const authFieldBorder = Color(0xFFF5F5F7);
  static const authInputBackground = Color(0xFFF5F5F7);
  static const dotInactiveLight = Color(0xFFE2E8F0);

  /// Hint and secondary text on the light auth/onboarding pages, and the tint
  /// of the terms strip at the foot of Sign In.
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);

  /// Neutral greys of the Explore design: a secondary line under a title, and
  /// the soft card behind a compact item.
  static const gray500 = Color(0xFF6B7280);
  static const gray200 = Color(0xFFE5E7EB);

  /// The hairline around a white pill or card on the light page (Podcasts'
  /// filter chips).
  static const softBorder = Color(0xFFF5F5F7);

  /// The deep blue behind the Ambient Music page.
  static const ambientNavy = Color(0xFF1D2A44);

  /// The other Ambient Music moods' banner colours, sampled from their card
  /// artwork so the details page's background follows the card it was
  /// opened from.
  static const ambientOlive = Color(0xFF9CA485);
  static const ambientGold = Color(0xFFCD9641);
  static const ambientLavender = Color(0xFFA5A3E1);
  static const ambientTeal = Color(0xFF3E7C8C);
  static const ambientMaroon = Color(0xFF8C3B3B);
  static const ambientOrange = Color(0xFFF35738);

  /// The soft grey-violet of long-form body text (the Privacy Policy).
  static const mutedInk = Color(0xFF868DA6);
  static const authFooterBackground = Color(0xFFEEF0F3);

  /// The violet → blue brand gradient from the onboarding design: mostly
  /// vertical with a slight diagonal (screen backdrops), a near-vertical one
  /// for the logo badge, and a horizontal one for wide buttons.
  static const brandGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [brand400, brandBlue],
  );
  static const brandBadgeGradient = LinearGradient(
    begin: Alignment(-0.15, -1),
    end: Alignment(0.15, 1),
    colors: [brand400, brandBlue],
  );
  static const brandButtonGradient = LinearGradient(
    colors: [brand400, brand600, brandBlue],
    stops: [0, 0.55, 1],
  );

  static const lightSurface = pageBackground;
  static const lightInk = Color(0xFF0E1122);
  static const lightInkSoft = Color(0xFF565B73);

  static const darkSurface = Color(0xFF0B0D16);
  static const darkInk = Color(0xFFF2F4FB);
  static const darkInkSoft = Color(0xFFA6ADC4);
}
