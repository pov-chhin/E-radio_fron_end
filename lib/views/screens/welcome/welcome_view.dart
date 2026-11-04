import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supports/continue_with_google.dart';
import '../../themes/app_colors.dart';
import '../../themes/light_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/eradio_logo_mark.dart';
import '../../widgets/shared/google_g_logo.dart';
import '../../widgets/shared/gradient_pill_button.dart';
import '../../widgets/onboarding/onboarding_skip_button.dart';
import '../../../providers/auth_controller.dart';
import '../../widgets/profile/auth_link_row.dart';
import '../../widgets/profile/auth_terms_footer.dart';

/// The optional sign-up offered once, right after onboarding: continue with
/// Google, create an account, or sign in — or Skip and just browse. Signing in
/// or up from here (through the screens it opens) carries straight on to
/// Explore, so this page never lingers behind a finished sign-in.
class WelcomeView extends ConsumerWidget {
  const WelcomeView({super.key});

  void _skip(BuildContext context) => context.go('/explore');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    ref.listen(authControllerProvider, (previous, next) {
      if (previous == null && next != null) context.go('/explore');
    });

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
              OnboardingSkipButton(onSkip: () => _skip(context)),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: EradioLogoMark(size: 128)),
                            const SizedBox(height: 20),
                            Text(
                              l10n.welcome,
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
                            const SizedBox(height: 28),
                            GradientPillButton(
                              label: l10n.continueWithGoogle,
                              leading: const GoogleBadge(),
                              onPressed: () => continueWithGoogle(context, ref),
                            ),
                            const SizedBox(height: 16),
                            const _OrDivider(),
                            const SizedBox(height: 16),
                            _SecondaryPillButton(
                              label: l10n.signUp,
                              onPressed: () => context.push('/profile/signup'),
                            ),
                            const SizedBox(height: 20),
                            AuthLinkRow(
                              prompt: l10n.haveAnAccount,
                              link: l10n.signInLink,
                              onTap: () => context.push('/profile/login'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                const AuthTermsFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.dotInactiveLight, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            l10n.orDivider,
            style: const TextStyle(color: AppColors.slate400, fontSize: 11),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.dotInactiveLight, height: 1),
        ),
      ],
    );
  }
}

/// The quieter grey pill under the gradient one.
class _SecondaryPillButton extends StatelessWidget {
  const _SecondaryPillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.authInputBackground,
          foregroundColor: AppColors.lightInk,
          shape: const StadiumBorder(
            side: BorderSide(color: AppColors.chipBorder),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
