import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'release_alert_provider.dart';
import 'shared_preferences_provider.dart';

const _kNotificationsEnabledKey = 'notifications_enabled';

/// Whether notifications are switched on, as saved (on, until switched off).
/// For code that runs outside the app's providers — the background check for
/// new releases.
bool savedNotificationsEnabled(SharedPreferences prefs) =>
    prefs.getBool(_kNotificationsEnabledKey) ?? true;

/// The on/off switch for notifications, kept on the device. Switching it
/// starts or stops the phone's background check for new releases, which is what
/// puts them in the notification bar (see `release_alerts.dart`); there is no
/// push-notification backend (FCM/APNs) behind it.
class NotificationsPrefController extends Notifier<bool> {
  @override
  bool build() =>
      savedNotificationsEnabled(ref.read(sharedPreferencesProvider));

  void setEnabled(bool enabled) {
    state = enabled;
    ref
        .read(sharedPreferencesProvider)
        .setBool(_kNotificationsEnabledKey, enabled);
    ref.read(releaseAlertSchedulerProvider).sync(enabled);
  }
}

final notificationsPrefProvider =
    NotifierProvider<NotificationsPrefController, bool>(
      NotificationsPrefController.new,
    );
