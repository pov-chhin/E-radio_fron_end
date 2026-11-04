import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supports/continue_with_google.dart';
import '../../themes/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../shared/google_g_logo.dart';

/// "Continue with Google" under the sign-up form. A new Google account is made
/// an e-Radio account on the spot, an existing one signed in, and either way
/// the page closes behind it like it does after a finished sign-up. Says
/// "Coming soon" while no Google client ID is set (see
/// AppConfig.googleServerClientId).
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.lightInk,
          side: const BorderSide(color: AppColors.chipBorder),
          shape: const StadiumBorder(),
        ),
        onPressed: () async {
          final result = await continueWithGoogle(context, ref);
          if (result == GoogleSignInResult.signedIn && context.mounted) {
            context.pop();
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GoogleGLogo(size: 20),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                l10n.continueWithGoogle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
