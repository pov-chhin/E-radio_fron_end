import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';

/// Google's account sheet closed by itself, far sooner than anyone could have
/// chosen an account. Android reports "there is no Google account on this
/// device" and "this app is not set up for Google sign-in" as the person
/// cancelling, so this is how those two are told from a real cancel.
class GoogleSignInClosedEarly implements Exception {
  const GoogleSignInClosedEarly();

  @override
  String toString() =>
      'Google closed its account sheet at once: no Google account on this '
      'device, or this app has no Android OAuth client for Google sign-in.';
}

/// Google turned the app down, and said why ([reason], in Google's own words —
/// e.g. "[16] Account reauth failed." when the app's package name or signing
/// key is not registered in Google Cloud). Android reports some of these as the
/// person cancelling, so the wording is what tells them apart.
class GoogleSignInRefused implements Exception {
  const GoogleSignInRefused(this.reason);

  final String reason;

  @override
  String toString() => 'Google refused the sign-in: $reason';
}

/// Whether the text Google gave with a "cancelled" is just the person closing
/// the sheet, which says nothing worth showing — or no text at all.
@visibleForTesting
bool isPlainCancel(String? description) {
  final text = description?.trim().toLowerCase() ?? '';
  // "activity is cancelled by the user." (Credential Manager) or
  // "[16] Cancelled by user." (Google Play services), either spelling.
  return text.isEmpty || RegExp(r'cancel+ed by (the )?user').hasMatch(text);
}

/// Whether a "cancelled" that came [elapsed] after the sheet was asked for was
/// too soon to be a person's choice.
@visibleForTesting
bool closedTooSoonToBeAChoice(Duration elapsed) =>
    elapsed < const Duration(milliseconds: 1500);

/// Google's side of "Continue with Google": the account picker, and the ID
/// token it hands back for the backend (`POST /auth/google`) to check.
class GoogleSignInService {
  GoogleSignInService({this.serverClientId = AppConfig.googleServerClientId});

  /// The Web client ID the ID token is issued for — see
  /// [AppConfig.googleServerClientId].
  final String serverClientId;

  Future<void>? _initialized;

  /// False until a client ID is set, and on platforms the plugin cannot sign
  /// in on (Windows, Linux).
  bool get isAvailable {
    if (serverClientId.isEmpty) return false;
    try {
      return GoogleSignIn.instance.supportsAuthenticate();
    } catch (_) {
      return false;
    }
  }

  /// The plugin must be initialised exactly once, and before anything else.
  Future<void> _ensureInitialized() => _initialized ??= GoogleSignIn.instance
      .initialize(serverClientId: serverClientId)
      .catchError((Object error) {
        _initialized = null; // Let the next tap try again.
        throw error;
      });

  /// The ID token for the account the person picks, or null if they closed
  /// the picker without choosing one. Throws [GoogleSignInClosedEarly] if the
  /// picker shut at once, which a person cannot have done, and
  /// [GoogleSignInRefused] if Google turned the app down and said why.
  Future<String?> signIn() async {
    await _ensureInitialized();
    final asked = Stopwatch()..start();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw StateError('Google gave no ID token.');
      return idToken;
    } on GoogleSignInException catch (error) {
      debugPrint(
        'Google sign-in: ${error.code.name} after ${asked.elapsed}: '
        '${error.description} ${error.details ?? ''}',
      );
      if (error.code == GoogleSignInExceptionCode.canceled) {
        if (closedTooSoonToBeAChoice(asked.elapsed)) {
          throw const GoogleSignInClosedEarly();
        }
        if (isPlainCancel(error.description)) return null;
      }
      throw GoogleSignInRefused(error.description ?? error.code.name);
    }
  }

  /// Best-effort: forgets the Google account too, so the next sign-in offers
  /// the picker again instead of reusing this one.
  Future<void> signOut() async {
    if (!isAvailable) return;
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Signing out of the app must not depend on Google being reachable.
    }
  }
}

final googleSignInServiceProvider = Provider<GoogleSignInService>(
  (ref) => GoogleSignInService(),
);
