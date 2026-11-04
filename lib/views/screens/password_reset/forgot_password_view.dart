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
import '../../widgets/profile/auth_link_row.dart';
import '../../widgets/profile/auth_text_field.dart';
import '../../../data/models/password_reset_args.dart';

/// Step 1 of the forgotten-password flow: ask for an emailed code. Reached from
/// Sign In's "Forgot password?" (email carried over if already typed) and from
/// Change Password's "Forgot current password?" (the signed-in email).
class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final expiresIn = await ref
          .read(passwordResetRepositoryProvider)
          .requestCode(email);
      if (!mounted) return;
      context.push(
        '/profile/forgot-password/code',
        extra: ResetCodeArgs(email: email, expiresIn: expiresIn),
      );
    } on ApiException catch (e) {
      setState(
        () => _error = e.statusCode == 429
            ? l10n.pleaseWaitAndRetry
            : (e.fieldError('email') ?? e.message),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final signedIn = ref.watch(authControllerProvider) != null;

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
            l10n.forgotPasswordTitle,
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
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F0FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    size: 36,
                    color: AppColors.brand400,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.forgotPasswordHeading,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.lightInk,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  l10n.forgotPasswordSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.slate500,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AuthTextField(
                controller: _email,
                label: l10n.emailAddress,
                hint: l10n.emailHintLong,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _send(),
                validator: (v) => (v == null || !v.trim().contains('@'))
                    ? l10n.emailInvalid
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              GradientPillButton(
                label: l10n.sendResetCode,
                trailingIcon: Icons.arrow_forward_rounded,
                loading: _sending,
                onPressed: _send,
              ),
              if (!signedIn) ...[
                const SizedBox(height: 28),
                AuthLinkRow(
                  prompt: l10n.backTo,
                  link: l10n.signInLink,
                  onTap: () => context.go('/profile/login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
