import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supports/coming_soon.dart';
import '../../themes/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';

/// The grey strip at the foot of Sign In: "By continuing, you agree to our
/// Terms and Privacy Policy." Privacy Policy opens its screen; there's no
/// Terms page yet, so that link says "Coming soon" rather than going nowhere.
class AuthTermsFooter extends StatefulWidget {
  const AuthTermsFooter({
    super.key,
    this.background = AppColors.authFooterBackground,
    this.textColor = AppColors.slate500,
    this.linkFontSize = 14,
    this.linkWeight = FontWeight.w400,
    this.bottomPadding = 10,
  });

  /// The strip's colour, its text, the links' size and weight, and the space
  /// under the text (the device's bottom inset is added to it).
  final Color background;
  final Color textColor;
  final double linkFontSize;
  final FontWeight linkWeight;
  final double bottomPadding;

  @override
  State<AuthTermsFooter> createState() => _AuthTermsFooterState();
}

class _AuthTermsFooterState extends State<AuthTermsFooter> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => showComingSoon(context);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => context.push('/profile/privacy-policy');

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final base = TextStyle(color: widget.textColor, fontSize: 14, height: 1.43);
    final link = base.copyWith(
      color: AppColors.brandBlue,
      fontSize: widget.linkFontSize,
      fontWeight: widget.linkWeight,
      height: 20 / widget.linkFontSize,
      decoration: TextDecoration.underline,
    );

    return Container(
      width: double.infinity,
      color: widget.background,
      padding: EdgeInsets.fromLTRB(
        32,
        24,
        32,
        widget.bottomPadding + MediaQuery.paddingOf(context).bottom,
      ),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(text: l10n.termsPrefix),
            TextSpan(text: l10n.termsLink, style: link, recognizer: _terms),
            TextSpan(text: l10n.termsAnd),
            TextSpan(text: l10n.privacyLink, style: link, recognizer: _privacy),
            TextSpan(text: l10n.termsSuffix),
          ],
        ),
      ),
    );
  }
}
