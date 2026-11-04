import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/api_client.dart';
import '../data/services/google_sign_in_service.dart';
import 'shared_preferences_provider.dart';
import '../data/models/user_profile.dart';

const _kTokenKey = 'auth_token';
const _kProfileKey = 'auth_profile';

/// Backed by the real e-Radio API (Sanctum token auth against the
/// Src\CmsAdmin\Models\User "customer" guard) — no more local mock.
class AuthController extends Notifier<UserProfile?> {
  @override
  UserProfile? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final token = prefs.getString(_kTokenKey);
    final raw = prefs.getString(_kProfileKey);
    if (token == null || raw == null) return null;
    return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  String? get token =>
      ref.read(sharedPreferencesProvider).getString(_kTokenKey);

  Future<void> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final client = ref.read(apiClientProvider);
    final res = await client.post('/register', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
    });
    await _persistSession(res as Map<String, dynamic>);
  }

  Future<void> signIn({required String email, required String password}) async {
    final client = ref.read(apiClientProvider);
    final res = await client.post('/login', {
      'email': email,
      'password': password,
    });
    await _persistSession(res as Map<String, dynamic>);
  }

  /// "Continue with Google": the ID token Google issues on the device is
  /// exchanged with the API for the same session a password sign-in gives (a
  /// new account is made if this Google account has none). False if the person
  /// closed Google's account picker, with nothing changed.
  Future<bool> signInWithGoogle() async {
    final idToken = await ref.read(googleSignInServiceProvider).signIn();
    if (idToken == null) return false;
    final res = await ref.read(apiClientProvider).post('/auth/google', {
      'id_token': idToken,
    });
    await _persistSession(res as Map<String, dynamic>);
    return true;
  }

  Future<void> signOut() async {
    final currentToken = token;
    if (currentToken != null) {
      try {
        await ref
            .read(apiClientProvider)
            .post('/logout', {}, token: currentToken);
      } catch (_) {
        // Token may already be invalid server-side; clear local session regardless.
      }
    }
    await ref.read(googleSignInServiceProvider).signOut();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kProfileKey);
    state = null;
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    String? address,
    String? phoneNumber,
  }) async {
    final client = ref.read(apiClientProvider);
    final res = await client.put('/me', {
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'address': address,
      'phone_number': phoneNumber,
    }, token: token);
    final profile = UserProfile.fromJson(
      (res as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
    await _saveProfile(profile);
  }

  Future<void> updateAvatar(String filePath) async {
    final res = await ref
        .read(apiClientProvider)
        .postFile(
          '/me/avatar',
          field: 'avatar',
          filePath: filePath,
          token: token,
        );
    await _saveProfile(
      UserProfile.fromJson(
        (res as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      ),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final client = ref.read(apiClientProvider);
    await client.put('/me/password', {
      'current_password': currentPassword,
      'password': newPassword,
    }, token: token);
  }

  Future<void> _saveProfile(UserProfile profile) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kProfileKey, jsonEncode(profile.toJson()));
    state = profile;
  }

  Future<void> _persistSession(Map<String, dynamic> res) async {
    final profile = UserProfile.fromJson(res['user'] as Map<String, dynamic>);
    final newToken = res['token'] as String;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kTokenKey, newToken);
    await prefs.setString(_kProfileKey, jsonEncode(profile.toJson()));
    state = profile;
  }
}

final authControllerProvider = NotifierProvider<AuthController, UserProfile?>(
  AuthController.new,
);
