import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';

const _kHasSeenOnboardingKey = 'has_seen_onboarding';

class HasSeenOnboardingController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kHasSeenOnboardingKey) ??
      false;

  Future<void> markSeen() async {
    state = true;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kHasSeenOnboardingKey, true);
  }
}

final hasSeenOnboardingProvider =
    NotifierProvider<HasSeenOnboardingController, bool>(
      HasSeenOnboardingController.new,
    );
