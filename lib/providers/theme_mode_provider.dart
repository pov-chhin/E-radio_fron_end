import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';

const _kThemeModeKey = 'theme_mode';

/// Follows the phone's light/dark setting until the user flips the Dark Mode
/// switch on the Account screen, after which their explicit choice sticks.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return switch (ref
        .read(sharedPreferencesProvider)
        .getString(_kThemeModeKey)) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  void setDark(bool dark) {
    state = dark ? ThemeMode.dark : ThemeMode.light;
    ref
        .read(sharedPreferencesProvider)
        .setString(_kThemeModeKey, dark ? 'dark' : 'light');
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
