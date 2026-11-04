import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'privacy_policy_text.dart';

/// The Privacy Policy: a back arrow, a centred title, and the policy text
/// centred beneath in a soft grey, scrolling as far as it needs to.
class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.mutedInk;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(l10n.privacyLink)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Text(
          kPrivacyPolicyText,
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontSize: 14, height: 1.55),
        ),
      ),
    );
  }
}
