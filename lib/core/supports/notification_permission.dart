import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/reminder_service.dart';
import '../../providers/notifications_pref_provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../providers/reminder_provider.dart';

const _kAskedNotificationPermissionKey = 'asked_notification_permission';

/// Whether the one-time prompt has already been scheduled or shown.
bool notificationPermissionWasAsked(SharedPreferences prefs) =>
    prefs.getBool(_kAskedNotificationPermissionKey) ?? false;

/// Android 13+ keeps every notification — new-release alerts, reminders, and
/// the media card with the lock-screen player — out of the notification list
/// until POST_NOTIFICATIONS is granted. Notifications are on by default, so ask
/// once, as the app opens (and again before the first play, which shares this
/// flag, if that comes first); never nag after that, the person can still grant
/// it from the Notifications switch, a reminder, or system settings.
Future<void> askNotificationPermissionOnce(
  SharedPreferences prefs,
  ReminderService reminders,
) async {
  if (notificationPermissionWasAsked(prefs)) return;
  await prefs.setBool(_kAskedNotificationPermissionKey, true);
  try {
    await reminders.requestPermission();
  } catch (error) {
    debugPrint('Notification permission request failed: $error');
  }
}

/// Asks the system for permission to show notifications and, only if it's
/// given, turns the app's switch on — so the switch never claims something the
/// phone won't do. Says so when permission is refused. Returns whether it was
/// granted.
Future<bool> turnOnNotifications(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  final granted = await ref.read(reminderServiceProvider).requestPermission();
  if (granted) {
    ref.read(notificationsPrefProvider.notifier).setEnabled(true);
  } else {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.notificationsPermissionNeeded)),
    );
  }
  return granted;
}
