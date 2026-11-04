import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';

/// "Have an account? Sign in" — muted prompt text followed by an underlined
/// link that does [onTap].
class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({
    super.key,
    required this.prompt,
    required this.link,
    required this.onTap,
    this.alignment = MainAxisAlignment.center,
    this.fontSize = 14,
    this.textColor = AppColors.slate500,
    this.linkColor,
    this.linkWeight = FontWeight.w400,
  });

  final String prompt;
  final String link;
  final VoidCallback onTap;
  final MainAxisAlignment alignment;
  final double fontSize;

  /// The prompt's colour; the link shares it unless [linkColor] says otherwise.
  final Color textColor;
  final Color? linkColor;
  final FontWeight linkWeight;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: textColor, fontSize: fontSize, height: 1.5);
    return Row(
      mainAxisAlignment: alignment,
      children: [
        Flexible(child: Text('$prompt ', style: style)),
        InkWell(
          onTap: onTap,
          child: Text(
            link,
            style: style.copyWith(
              decoration: TextDecoration.underline,
              fontWeight: linkWeight,
              color: linkColor,
            ),
          ),
        ),
      ],
    );
  }
}
