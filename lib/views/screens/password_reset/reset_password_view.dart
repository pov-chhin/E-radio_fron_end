import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../themes/app_colors.dart';
import '../../../data/services/api_exception.dart';
import '../../themes/light_theme.dart';
import '../../../data/repositories/password_reset_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/gradient_pill_button.dart';
import '../../../providers/auth_controller.dart';
import '../../widgets/profile/auth_text_field.dart';
import '../../widgets/profile/password_requirements.dart';
import '../../../data/models/password_reset_args.dart';

/// Step 3: choose the new password. The checklist shows the four rules the
/// server enforces, lighting up as they're met. Once it's set, every session on
/// the account is ended server-side, so this signs the app out too and sends
/// the person to Sign In.
class ResetPasswordView extends ConsumerStatefulWidget {
  const ResetPasswordView({super.key, required this.args});

  final ResetPasswordArgs args;

  @override
  ConsumerState<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends ConsumerState<ResetPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Re-evaluate the checklist on every keystroke in the new-password field.
    _new.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(passwordResetRepositoryProvider)
          .resetPassword(
            email: widget.args.email,
            resetToken: widget.args.resetToken,
            password: _new.text,
          );
      // Resetting ended every session on the account, this device's included.
      if (ref.read(authControllerProvider) != null) {
        await ref.read(authControllerProvider.notifier).signOut();
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordResetDone)));
      router.go('/profile/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.fieldError('reset_token') != null
            ? l10n.resetExpired
            : (e.fieldError('password') ?? e.message),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Part of the light-only auth flow (see the Sign In screen).
    return Theme(
      data: lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: AppColors.pageBackground,
          surfaceTintColor: Colors.transparent,
          title: Text(
            l10n.resetPassword,
            style: const TextStyle(
              color: AppColors.lightInk,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF1F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 26,
                    color: AppColors.lightInk,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.createNewPassword,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.lightInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.createNewPasswordSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slate500, fontSize: 13),
              ),
              const SizedBox(height: 28),
              AuthTextField(
                controller: _new,
                label: l10n.newPassword,
                isPassword: true,
                validator: (v) =>
                    PasswordRules.allMet(PasswordRules.reset, v ?? '')
                    ? null
                    : l10n.passwordRequirementsNotMet,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _confirm,
                label: l10n.confirmPassword,
                isPassword: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) =>
                    v != _new.text ? l10n.passwordsDontMatch : null,
              ),
              const SizedBox(height: 22),
              PasswordChecklist(
                password: _new.text,
                rules: PasswordRules.reset,
                filledIcons: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              GradientPillButton(
                label: l10n.resetPassword,
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
