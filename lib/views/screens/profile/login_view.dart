import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supports/continue_with_google.dart';
import '../../themes/app_colors.dart';
import '../../themes/light_theme.dart';
import '../../../data/services/api_exception.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/google_g_logo.dart';
import '../../widgets/shared/gradient_pill_button.dart';
import '../../widgets/shared/see_all_header.dart';
import '../../../providers/auth_controller.dart';
import '../../widgets/profile/auth_link_row.dart';
import '../../widgets/profile/auth_terms_footer.dart';
import '../../widgets/profile/auth_text_field.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
          .signIn(email: _email.text.trim(), password: _password.text);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      setState(() => _error = e.fieldError('email') ?? e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// "Continue with Google": closes the page once signed in. Says "Coming soon"
  /// while no Google client ID is set, and what went wrong if it did not finish.
  Future<void> _google() async {
    final result = await continueWithGoogle(context, ref);
    if (result == GoogleSignInResult.signedIn && mounted) context.pop();
  }

  /// Starts the forgotten-password flow, with the email if one's been typed.
  void _forgotPassword() {
    final typed = _email.text.trim();
    context.push(
      '/profile/forgot-password',
      extra: typed.contains('@') ? typed : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    // The design for these screens is light-only, so they stay light even
    // when Dark Mode is on.
    return Theme(
      data: lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Just the back arrow — this page has no title in its bar.
              const SeeAllHeader(title: ''),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    // Centred in the space above the footer; scrolls if the
                    // keyboard leaves too little room.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Center(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.welcomeBack,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.lightInk,
                                  fontSize: 32,
                                  height: 1.25,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.authSubtitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.slate500,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 34),
                              AuthTextField(
                                controller: _email,
                                label: l10n.emailAddress,
                                hint: 'name@example.com',
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) =>
                                    (v == null || !v.trim().contains('@'))
                                    ? l10n.emailInvalid
                                    : null,
                              ),
                              const SizedBox(height: 24),
                              AuthTextField(
                                controller: _password,
                                label: l10n.password,
                                isPassword: true,
                                // The eye sits before the text, as designed.
                                toggleAtStart: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? l10n.fieldRequired
                                    : null,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: _forgotPassword,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      l10n.forgotPassword,
                                      style: const TextStyle(
                                        color: AppColors.slate500,
                                        fontSize: 14,
                                        height: 1.55,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              const SizedBox(height: 24),
                              GradientPillButton(
                                label: l10n.login,
                                trailingIcon: Icons.arrow_forward_rounded,
                                loading: _submitting,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 16),
                              // A Google account is made an e-Radio account on
                              // the spot, or signed in; either way this page
                              // closes behind it, as after a Login.
                              GradientPillButton(
                                label: l10n.continueWithGoogle,
                                leading: const GoogleBadge(),
                                onPressed: _submitting ? null : _google,
                              ),
                              const SizedBox(height: 24),
                              AuthLinkRow(
                                prompt: l10n.noAccount,
                                link: l10n.signUpLink,
                                alignment: MainAxisAlignment.start,
                                fontSize: 16,
                                onTap: () =>
                                    context.pushReplacement('/profile/signup'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!keyboardOpen) const AuthTermsFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
