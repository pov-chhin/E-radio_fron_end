import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/services/radio_audio_handler.dart';
import '../../data/services/release_alerts.dart';
import '../../data/services/reminder_service.dart';
import '../../data/services/app_database.dart';
import '../../providers/notifications_pref_provider.dart';
import '../../providers/release_alert_provider.dart';
import '../supports/notification_permission.dart';

/// Everything `main()` needs before it can call `runApp` — resolved here so
/// `main.dart` stays a thin entry point. Mirrors 988score-app's
/// `core/bootstrap/app_bootstrap.dart`, adapted to return the instances
/// Riverpod's `ProviderScope` overrides need rather than only performing
/// side effects.
class AppBootstrap {
  AppBootstrap._();

  static Future<AppBootstrapResult> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Taps on notifications, from the plugin to the app. A broadcast stream
    // drops what arrives before the app listens — fine: the tap that started
    // the app is read separately below.
    final notificationTaps = StreamController<String>.broadcast();
    // Four independent startups, run together: the launch takes as long as the
    // slowest of them rather than all of them one after another.
    final (prefs, database, audioHandler, notifications) = await (
      SharedPreferences.getInstance(),
      AppDatabase.open(),
      // The lock-screen and notification player. Wired to the app's player by
      // AudioPlayerController, which owns the list that previous/next step through.
      AudioService.init(
        builder: RadioAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.eradio.ams_e_radio.channel.audio',
          androidNotificationChannelName: 'AMS ERadio playback',
          androidNotificationIcon: 'drawable/ic_stat_radio',
          androidNotificationOngoing: true,
        ),
      ),
      _initNotifications(notificationTaps.sink),
    ).wait;
    final reminderService = ReminderService(notifications);
    final launchNotificationPayload = await _launchPayload(notifications);

    // The phone's own check for new releases, for the notification bar: on if
    // notifications are, and the Notifications switch turns it on and off.
    final releaseAlerts = WorkmanagerReleaseAlerts(prefs);
    unawaited(releaseAlerts.sync(savedNotificationsEnabled(prefs)));

    // Notifications are on until switched off, but Android 13+ shows none until
    // the person allows them — so ask once, over the first frame (the answer
    // isn't awaited: the app must not wait on a dialog).
    if (savedNotificationsEnabled(prefs)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(askNotificationPermissionOnce(prefs, reminderService)),
      );
    }

    return AppBootstrapResult(
      prefs: prefs,
      database: database,
      reminderService: reminderService,
      audioHandler: audioHandler,
      releaseAlerts: releaseAlerts,
      notificationTaps: notificationTaps.stream,
      launchNotificationPayload: launchNotificationPayload,
    );
  }

  /// The payload of the notification whose tap started the app from closed;
  /// null when it was started any other way.
  static Future<String?> _launchPayload(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    try {
      final launch = await plugin.getNotificationAppLaunchDetails();
      return launch?.didNotificationLaunchApp == true
          ? launch?.notificationResponse?.payload
          : null;
    } catch (error) {
      debugPrint('Launch notification unavailable: $error');
      return null;
    }
  }

  /// Best-effort: on a platform the plugin doesn't support (e.g. this app run
  /// as a Windows desktop build) reminders are silently unavailable rather
  /// than crashing startup.
  static Future<FlutterLocalNotificationsPlugin> _initNotifications(
    Sink<String> taps,
  ) async {
    final plugin = FlutterLocalNotificationsPlugin();
    try {
      tz_data.initializeTimeZones();
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) taps.add(payload);
        },
      );
    } catch (error) {
      debugPrint('Reminder notifications unavailable: $error');
    }
    return plugin;
  }
}

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.prefs,
    required this.database,
    required this.reminderService,
    required this.audioHandler,
    required this.releaseAlerts,
    required this.notificationTaps,
    required this.launchNotificationPayload,
  });

  final SharedPreferences prefs;
  final Database database;
  final ReminderService reminderService;
  final RadioAudioHandler audioHandler;
  final ReleaseAlertScheduler releaseAlerts;

  /// The payload of every notification tapped while the app runs.
  final Stream<String> notificationTaps;

  /// The payload of the notification that started the app, if one did.
  final String? launchNotificationPayload;
}
