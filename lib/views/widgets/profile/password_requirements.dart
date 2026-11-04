import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';

/// One line of a password checklist: its wording and how to tell whether a
/// password meets it.
class PasswordRule {
  const PasswordRule(this.label, this.isMet);

  final String Function(AppLocalizations l10n) label;
  final bool Function(String password) isMet;
}

/// The password rules the design shows. The two checklists differ (each is its
/// own screen in the design); the reset one mirrors what the server enforces.
abstract final class PasswordRules {
  static bool hasMinLength(String p) => p.length >= 8;
  static bool hasNumberOrSymbol(String p) =>
      RegExp(r'[0-9]|[^A-Za-z0-9\s]').hasMatch(p);
  static bool hasUpperAndLower(String p) =>
      RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p);
  static bool hasUpper(String p) => RegExp(r'[A-Z]').hasMatch(p);
  static bool hasNumber(String p) => RegExp(r'[0-9]').hasMatch(p);

  /// Same test as the API's `regex:/[^A-Za-z0-9]/`.
  static bool hasSpecial(String p) => RegExp(r'[^A-Za-z0-9]').hasMatch(p);

  /// Change Password's checklist.
  static final change = <PasswordRule>[
    PasswordRule((l10n) => l10n.reqLength, hasMinLength),
    PasswordRule((l10n) => l10n.reqNumberOrSymbol, hasNumberOrSymbol),
    PasswordRule((l10n) => l10n.reqUpperLower, hasUpperAndLower),
  ];

  /// Reset Password's checklist — exactly what `POST /password/reset` demands.
  static final reset = <PasswordRule>[
    PasswordRule((l10n) => l10n.ruleLength, hasMinLength),
    PasswordRule((l10n) => l10n.ruleUppercase, hasUpper),
    PasswordRule((l10n) => l10n.ruleNumber, hasNumber),
    PasswordRule((l10n) => l10n.ruleSpecial, hasSpecial),
  ];

  static bool allMet(List<PasswordRule> rules, String password) =>
      rules.every((rule) => rule.isMet(password));
}

/// A live checklist: each rule lights up as [password] satisfies it. With
/// [filledIcons] a met rule is a solid green disc with a check and an unmet one
/// a pale grey disc (the Reset Password look); otherwise a bare green check.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({
    super.key,
    required this.password,
    required this.rules,
    this.filledIcons = false,
  });

  final String password;
  final List<PasswordRule> rules;
  final bool filledIcons;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in rules)
          _Rule(
            text: rule.label(l10n),
            met: rule.isMet(password),
            filled: filledIcons,
          ),
      ],
    );
  }
}

/// Change Password's "Requirements Checklist": a heading over its checklist.
class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.password});

  final String password;

  /// True when every rule in the checklist is met.
  static bool isValid(String p) =>
      PasswordRules.allMet(PasswordRules.change, p);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.requirementsChecklist,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        PasswordChecklist(password: password, rules: PasswordRules.change),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.text, required this.met, required this.filled});

  final String text;
  final bool met;
  final bool filled;

  static const _green = Color(0xFF22B573);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final Color textColor;
    final IconData icon;
    final Color iconColor;

    if (filled) {
      icon = met ? Icons.check_circle_rounded : Icons.circle;
      iconColor = met ? _green : colors.outlineVariant;
      textColor = met ? colors.onSurface : AppColors.slate400;
    } else {
      icon = met ? Icons.check_rounded : Icons.radio_button_unchecked_rounded;
      iconColor = met ? _green : AppColors.slate400;
      textColor = iconColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: textColor, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
