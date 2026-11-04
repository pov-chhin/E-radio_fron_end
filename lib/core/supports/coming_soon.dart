import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// For controls that are drawn as designed but have nothing behind them yet
/// (Google sign-in, forgot password, Terms, photo upload, …): say so plainly
/// rather than doing nothing.
void showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context)!.comingSoon)),
  );
}
