import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Local (on-device only, no backend) scheduling for the Now Playing screen's
/// "Remind me" toggle. `main.dart` initializes timezone data before any
/// schedule/cancel call is made.
class ReminderService {
  ReminderService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'com.eradio.ams_e_radio.channel.reminders';
  static const _channelName = 'AMS ERadio reminders';

  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? true;
    }
    return true;
  }

  Future<void> schedule({
    required String itemId,
    required String title,
    required DateTime at,
  }) async {
    await _plugin.zonedSchedule(
      id: _notificationId(itemId),
      title: title,
      body: "It's time — tap to tune back in",
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(String itemId) =>
      _plugin.cancel(id: _notificationId(itemId));

  /// Stable per-item id so re-scheduling the same item replaces, not duplicates.
  static int _notificationId(String itemId) => itemId.hashCode & 0x7fffffff;
}
