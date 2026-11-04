import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/google_sign_in_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers/auth_controller.dart';

/// How a tap on "Continue with Google" ended.
enum GoogleSignInResult {
  /// Signed in (or signed up — the first time a Google account is used).
  signedIn,

  /// Google's account picker ended without an account — the person closed it,
  /// or (Android reports both alike) Google turned the app down after they
  /// chose one. Either way no one is signed in, so the page says so.
  cancelled,

  /// No Google client ID is set (or this platform has no Google sign-in), so
  /// there is nothing behind the button yet.
  unavailable,

  /// Google's account sheet shut at once — no Google account on the device, or
  /// the app isn't set up for Google sign-in — which isn't the person's doing.
  closedEarly,

  /// Google turned the app down and said why (see [GoogleSignInRefused]) — the
  /// reason is shown with the message so the cause can be read off the phone.
  refused,

  /// Google or the API let them down.
  failed,
}

/// How a tap ended, with — when Google refused the app — what it said.
typedef GoogleSignInOutcome = ({GoogleSignInResult result, String? reason});

/// Runs "Continue with Google" for any of its buttons. Never throws; read
/// [ref] before the first await only — the button's page may be gone by the
/// time this finishes (a finished sign-in sends the welcome page on to Explore).
Future<GoogleSignInOutcome> trySignInWithGoogle(WidgetRef ref) async {
  GoogleSignInOutcome ended(GoogleSignInResult result, [String? reason]) =>
      (result: result, reason: reason);

  if (!ref.read(googleSignInServiceProvider).isAvailable) {
    return ended(GoogleSignInResult.unavailable);
  }
  try {
    final signedIn = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    return ended(
      signedIn ? GoogleSignInResult.signedIn : GoogleSignInResult.cancelled,
    );
  } on GoogleSignInClosedEarly catch (error) {
    debugPrint('Google sign-in: $error');
    return ended(GoogleSignInResult.closedEarly);
  } on GoogleSignInRefused catch (error) {
    debugPrint('Google sign-in: $error');
    return ended(GoogleSignInResult.refused, error.reason);
  } catch (error, stackTrace) {
    debugPrint('Google sign-in failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    return ended(GoogleSignInResult.failed);
  }
}

/// Says what went wrong, if anything went wrong.
void reportGoogleSignIn(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  GoogleSignInOutcome outcome,
) {
  final message = switch (outcome.result) {
    GoogleSignInResult.unavailable => l10n.comingSoon,
    GoogleSignInResult.cancelled => l10n.googleSignInCancelled,
    GoogleSignInResult.closedEarly => l10n.googleSignInClosedEarly,
    GoogleSignInResult.refused => l10n.googleSignInRefused(
      outcome.reason ?? '',
    ),
    GoogleSignInResult.failed => l10n.googleSignInFailed,
    GoogleSignInResult.signedIn => null,
  };
  if (message != null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// [trySignInWithGoogle], then [reportGoogleSignIn] — for a button that has
/// nothing else to do afterwards. Returns how it ended.
Future<GoogleSignInResult> continueWithGoogle(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  final outcome = await trySignInWithGoogle(ref);
  reportGoogleSignIn(messenger, l10n, outcome);
  return outcome.result;
}
