import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../themes/app_colors.dart';
import '../../../core/supports/continue_with_google.dart';
import '../../themes/light_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../shared/google_g_logo.dart';
import 'auth_link_row.dart';
import 'auth_terms_footer.dart';

/// The sheet that slides up when a guest tries something that needs an
/// account (saving a favorite, say): "Sign in — Log in to save your
/// favorites", Continue with Google, Create Account, and a link for people who
/// already have one.
Future<void> showSignInSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x33000000),
    builder: (sheetContext) => const SignInSheet(),
  );
}

class SignInSheet extends StatelessWidget {
  const SignInSheet({super.key});

  /// Closes the sheet, then goes to [path] on the page that opened it.
  void _goTo(BuildContext context, String path) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Sign-in is light whatever the app's theme is, like the other auth pages.
    return Theme(
      data: lightTheme,
      child: Builder(
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Color(0x296D758F),
                offset: Offset(0, 8),
                blurRadius: 14,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 64),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The 13px ✕ sits in a bigger tap area, nudged so the icon
                    // ends up where the design puts it.
                    Align(
                      alignment: Alignment.centerRight,
                      child: Transform.translate(
                        offset: const Offset(8, 0),
                        child: IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          iconSize: 13,
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints.tightFor(
                            width: 37,
                            height: 37,
                          ),
                          color: AppColors.lightInk,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.signInTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 32,
                              height: 40 / 32,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.signInSheetSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 16,
                              height: 24 / 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GoogleButton(label: l10n.continueWithGoogle),
                          _OrDivider(label: l10n.orDivider),
                          _CreateAccountButton(
                            label: l10n.signUp,
                            onPressed: () => _goTo(context, '/profile/signup'),
                          ),
                          const SizedBox(height: 20),
                          AuthLinkRow(
                            prompt: l10n.haveAnAccount,
                            link: l10n.signInLink,
                            linkColor: AppColors.brandBlue,
                            linkWeight: FontWeight.w500,
                            textColor: const Color(0xFF6B7280),
                            onTap: () => _goTo(context, '/profile/login'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const AuthTermsFooter(
                background: Color(0x80E2E5F7),
                textColor: AppColors.mutedInk,
                linkFontSize: 16,
                linkWeight: FontWeight.w500,
                bottomPadding: 44,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Google's button in the brand gradient, its "G" in a white disc. The sheet
/// closes once Google has answered — signed in, or failed, so the message is
/// not left hidden behind it — but stays if the account picker was just closed.
class _GoogleButton extends ConsumerWidget {
  const _GoogleButton({required this.label});

  final String label;

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final outcome = await trySignInWithGoogle(ref);
    if (outcome.result == GoogleSignInResult.cancelled) return;
    if (context.mounted) navigator.pop();
    reportGoogleSignIn(messenger, l10n, outcome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.brandButtonGradient,
          borderRadius: BorderRadius.circular(80),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(80),
          onTap: () => _continue(context, ref),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(child: GoogleGLogo(size: 20)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.pageBackground,
                    fontSize: 16,
                    height: 24 / 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: SizedBox(height: 1, child: ColoredBox(color: Color(0xFFE5E7EB))),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          line,
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              height: 20 / 14,
            ),
          ),
          const SizedBox(width: 12),
          line,
        ],
      ),
    );
  }
}

class _CreateAccountButton extends StatelessWidget {
  const _CreateAccountButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.softBorder,
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFFE5E7EB))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 16,
                height: 24 / 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
