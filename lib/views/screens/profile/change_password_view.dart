import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/api_exception.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/gradient_pill_button.dart';
import '../../../providers/auth_controller.dart';
import '../../widgets/profile/auth_text_field.dart';
import '../../widgets/profile/password_requirements.dart';

/// Change Password: current + new + confirmation, with the requirements
/// checklist ticking off live as the new password is typed.
class ChangePasswordView extends ConsumerStatefulWidget {
  const ChangePasswordView({super.key});

  @override
  ConsumerState<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends ConsumerState<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
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
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
        context.pop();
      }
    } on ApiException catch (e) {
      setState(() => _error = e.fieldError('current_password') ?? e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(l10n.changePassword)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            AuthTextField(
              controller: _current,
              label: l10n.currentPassword,
              isPassword: true,
              validator: (v) =>
                  (v == null || v.isEmpty) ? l10n.fieldRequired : null,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _new,
              label: l10n.newPassword,
              isPassword: true,
              validator: (v) => PasswordRequirements.isValid(v ?? '')
                  ? null
                  : l10n.passwordRequirementsNotMet,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _confirm,
              label: l10n.confirmNewPassword,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) => v != _new.text ? l10n.passwordsDontMatch : null,
            ),
            const SizedBox(height: 20),
            PasswordRequirements(password: _new.text),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            GradientPillButton(
              label: l10n.updatePassword,
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => context.push(
                  '/profile/forgot-password',
                  extra: ref.read(authControllerProvider)?.email,
                ),
                child: Text(
                  l10n.forgotCurrentPassword,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
