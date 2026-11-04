import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';

const _kOnboardingInterestsKey = 'onboarding_interests';

/// Genres/topics picked during onboarding. The backend has no schema yet to
/// filter feeds by this (see the flat single-level `tags` reality on
/// stations/media content), so today this is captured for later use rather
/// than acted on anywhere.
class OnboardingInterestsController extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      ref
          .read(sharedPreferencesProvider)
          .getStringList(_kOnboardingInterestsKey)
          ?.toSet() ??
      <String>{};

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) next.add(id);
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_kOnboardingInterestsKey, next.toList());
  }
}

final onboardingInterestsProvider =
    NotifierProvider<OnboardingInterestsController, Set<String>>(
      OnboardingInterestsController.new,
    );
