import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';

/// The forgotten-password endpoints, in the order the flow uses them:
/// ask for an emailed code, trade it for a reset token, set the new password.
/// None of them need a signed-in user.
class PasswordResetRepository {
  PasswordResetRepository(this._client);

  final ApiClient _client;

  /// Emails a 6-digit code to [email] (if there's an account for it — the
  /// server answers the same either way) and returns how many seconds the code
  /// stays valid.
  Future<int> requestCode(String email) async {
    final res = await _client.post('/password/forgot', {'email': email});
    return (res as Map<String, dynamic>)['expires_in'] as int;
  }

  /// Returns the reset token for a correct [code]; throws an `ApiException`
  /// with a `code` field error for a wrong, used or expired one.
  Future<String> verifyCode({
    required String email,
    required String code,
  }) async {
    final res = await _client.post('/password/verify-code', {
      'email': email,
      'code': code,
    });
    return (res as Map<String, dynamic>)['reset_token'] as String;
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String password,
  }) async {
    await _client.post('/password/reset', {
      'email': email,
      'reset_token': resetToken,
      'password': password,
    });
  }
}

final passwordResetRepositoryProvider = Provider<PasswordResetRepository>(
  (ref) => PasswordResetRepository(ref.read(apiClientProvider)),
);
