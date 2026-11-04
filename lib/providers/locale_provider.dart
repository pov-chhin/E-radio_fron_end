import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';

/// Where the chosen language is saved — read directly by code that runs outside
/// the app's providers (the background check for new releases).
const kLocaleKey = 'app_locale';
const kSupportedLocales = [Locale('en'), Locale('km')];

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final code = ref.read(sharedPreferencesProvider).getString(kLocaleKey);
    return kSupportedLocales.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => const Locale('en'),
    );
  }

  void setLocale(Locale locale) {
    state = locale;
    ref
        .read(sharedPreferencesProvider)
        .setString(kLocaleKey, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
