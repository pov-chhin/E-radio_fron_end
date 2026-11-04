import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';

/// A labelled, pill-shaped field for the sign-in / create-account forms: the
/// label sits above the field (not floating inside it), and a password field
/// gets a show/hide eye.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.isPassword = false,
    this.toggleAtStart = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool isPassword;

  /// Puts a password's show/hide eye at the left of the field, before the text,
  /// instead of at the right (as Sign In has it).
  final bool toggleAtStart;

  /// False greys the field out and stops edits (e.g. the email on Edit Profile).
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radius = BorderRadius.all(Radius.circular(80));
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color),
    );

    final eye = widget.isPassword
        ? IconButton(
            tooltip: _obscured ? l10n.showPassword : l10n.hidePassword,
            icon: Icon(
              _obscured
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: colors.onSurface,
              size: 20,
            ),
            onPressed: () => setState(() => _obscured = !_obscured),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            widget.label,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: widget.isPassword && _obscured,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          style: TextStyle(
            color: widget.enabled ? colors.onSurface : AppColors.slate400,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 16),
            filled: true,
            fillColor: !widget.enabled
                ? (isDark
                      ? colors.surfaceContainer
                      : AppColors.authFooterBackground)
                : (isDark ? colors.surfaceContainerHigh : Colors.white),
            constraints: const BoxConstraints(minHeight: 56),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 20, 8),
            enabledBorder: border(
              isDark ? colors.outlineVariant : AppColors.authFieldBorder,
            ),
            disabledBorder: border(
              isDark ? colors.outlineVariant : AppColors.authFieldBorder,
            ),
            focusedBorder: border(AppColors.brandBlue),
            errorBorder: border(Theme.of(context).colorScheme.error),
            focusedErrorBorder: border(Theme.of(context).colorScheme.error),
            prefixIcon: widget.toggleAtStart ? eye : null,
            suffixIcon: widget.toggleAtStart ? null : eye,
          ),
        ),
      ],
    );
  }
}
