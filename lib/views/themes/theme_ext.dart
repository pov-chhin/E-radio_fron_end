import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colours the Explore screens use for secondary text and soft cards, in the
/// design's neutral greys on the light theme and the theme's own tones on the
/// dark one.
extension AppThemeColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  /// A second line of text under a title, and "See All".
  Color get mutedText =>
      _isDark ? Theme.of(this).colorScheme.onSurfaceVariant : AppColors.gray500;

  /// The pill behind a compact item (a "Jump Back In" card).
  Color get softCard => _isDark
      ? Theme.of(this).colorScheme.surfaceContainerHigh
      : AppColors.gray200;

  /// A white card lifted off the page (a Podcasts episode row or filter chip).
  Color get raisedCard =>
      _isDark ? Theme.of(this).colorScheme.surfaceContainerHigh : Colors.white;

  /// The outline of a chip or button that has no fill of its own.
  Color get outline =>
      _isDark ? Theme.of(this).colorScheme.outlineVariant : AppColors.gray200;
}
