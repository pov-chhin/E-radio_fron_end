import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'providers/audio_handler_provider.dart';
import 'providers/database_provider.dart';
import 'providers/notification_tap_provider.dart';
import 'providers/release_alert_provider.dart';
import 'providers/shared_preferences_provider.dart';
import 'providers/reminder_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);

  final bootstrap = await AppBootstrap.init();

  runApp(
    ProviderScope(
      // A failed request shows its error (and a Retry button) straight away
      // rather than looking like it is still loading while Riverpod quietly
      // tries again for a minute.
      retry: (retryCount, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(bootstrap.prefs),
        databaseProvider.overrideWithValue(bootstrap.database),
        reminderServiceProvider.overrideWithValue(bootstrap.reminderService),
        audioHandlerProvider.overrideWithValue(bootstrap.audioHandler),
        releaseAlertSchedulerProvider.overrideWithValue(
          bootstrap.releaseAlerts,
        ),
        notificationTapsProvider.overrideWithValue(bootstrap.notificationTaps),
        launchNotificationPayloadProvider.overrideWithValue(
          bootstrap.launchNotificationPayload,
        ),
      ],
      child: const ERadioApp(),
    ),
  );
}
