import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../themes/app_colors.dart';
import '../../themes/light_theme.dart';
import '../../../data/services/api_exception.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/eradio_logo_mark.dart';
import '../../widgets/shared/gradient_pill_button.dart';
import '../../../providers/auth_controller.dart';
import '../../widgets/profile/auth_link_row.dart';
import '../../widgets/profile/auth_text_field.dart';
import '../../widgets/profile/google_signin_button.dart';

class SignUpView extends ConsumerStatefulWidget {
  const SignUpView({super.key});

  @override
  ConsumerState<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signUp(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
      if (mounted) context.pop();
    } on ApiException catch (e) {
      setState(() => _error = e.fieldError('email') ?? e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? l10n.fieldRequired : null;

    // The design for these screens is light-only, so they stay light even
    // when Dark Mode is on.
    return Theme(
      data: lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 44, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: EradioLogoMark(size: 80)),
                  const SizedBox(height: 20),
                  Text(
                    l10n.createAccount,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.lightInk,
                      fontSize: 32,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.authSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.slate500,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AuthTextField(
                    controller: _firstName,
                    label: l10n.firstName,
                    hint: l10n.firstNameHint,
                    validator: required,
                  ),
                  const SizedBox(height: 12),
                  AuthTextField(
                    controller: _lastName,
                    label: l10n.lastName,
                    hint: l10n.lastNameHint,
                    validator: required,
                  ),
                  const SizedBox(height: 12),
                  AuthTextField(
                    controller: _email,
                    label: l10n.emailAddress,
                    hint: 'name@example.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.trim().contains('@'))
                        ? l10n.emailInvalid
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AuthTextField(
                    controller: _password,
                    label: l10n.password,
                    isPassword: true,
                    validator: (v) => (v == null || v.length < 8)
                        ? l10n.passwordTooShort
                        : null,
                  ),
                  const SizedBox(height: 12),
                  AuthTextField(
                    controller: _confirmPassword,
                    label: l10n.confirmPassword,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: (v) =>
                        v != _password.text ? l10n.passwordsDontMatch : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  GradientPillButton(
                    label: l10n.createAccount,
                    trailingIcon: Icons.arrow_forward_rounded,
                    loading: _submitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 16),
                  const GoogleSignInButton(),
                  const SizedBox(height: 16),
                  AuthLinkRow(
                    prompt: l10n.haveAnAccount,
                    link: l10n.signInLink,
                    onTap: () => context.pushReplacement('/profile/login'),
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
