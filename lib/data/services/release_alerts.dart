import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/notifications_inbox_provider.dart';
import '../../providers/notifications_pref_provider.dart';
import '../../providers/release_alert_provider.dart';
import '../../views/themes/app_colors.dart';
import '../models/media_content.dart';
import 'api_client.dart';
import 'notification_image.dart';

/// New releases in the phone's notification bar, even with the app closed.
///
/// There is no push service behind the app (no FCM/APNs), so the phone asks for
/// itself: Android's WorkManager runs [releaseAlertsDispatcher] about every 15
/// minutes — the least it allows — when the phone has a connection. It fetches
/// the same feed as the Notifications page and announces what is new, by the
/// same rules as that page. Android may delay or skip a run to save battery,
/// and some makers' phones are stricter still.

const _kAnnouncedKey = 'notifications_announced_at';

/// Which of [releases] are worth a notification: published after the inbox was
/// last opened *and* after the last announcement, so nothing is announced twice
/// or after it was seen; not hidden, and not from a muted source. Sources the
/// person asked for fewer notifications from are left to the inbox. Newest
/// first.
List<MediaContent> releasesToAnnounce({
  required List<MediaContent> releases,
  required DateTime seen,
  required DateTime announced,
  required NotificationChoices choices,
}) {
  final after = seen.isAfter(announced) ? seen : announced;
  final fresh = [
    for (final release in choices.visible(releases))
      if ((release.publishedAt?.isAfter(after) ?? false) &&
          !choices.fewer.contains(NotificationChoices.sourceOf(release)))
        release,
  ];
  fresh.sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));
  return fresh;
}

/// One run of the check: fetch, decide, announce, remember. The pieces it needs
/// come in from outside so it can be tried without a phone.
class ReleaseAlertChecker {
  ReleaseAlertChecker({
    required this.prefs,
    required this.fetch,
    required this.show,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final SharedPreferences prefs;

  /// The newest releases, as the Notifications page lists them.
  final Future<List<MediaContent>> Function() fetch;

  /// Puts [releases] (newest first) in the notification bar.
  final Future<void> Function(List<MediaContent> releases) show;

  final DateTime Function() _now;

  /// Returns how many releases were announced. A failure in [fetch] or [show]
  /// leaves what was already announced untouched, so the next run tries again.
  Future<int> run() async {
    if (!savedNotificationsEnabled(prefs)) return 0;

    final announced = DateTime.tryParse(prefs.getString(_kAnnouncedKey) ?? '');
    if (announced == null) {
      // Never looked before: what is already out is not news.
      await prefs.setString(_kAnnouncedKey, _now().toIso8601String());
      return 0;
    }

    final fresh = releasesToAnnounce(
      releases: await fetch(),
      seen: savedNotificationsSeen(prefs) ?? announced,
      announced: announced,
      choices: savedNotificationChoices(prefs),
    );
    if (fresh.isEmpty) return 0;

    await show(fresh);
    await prefs.setString(
      _kAnnouncedKey,
      fresh.first.publishedAt!.toIso8601String(),
    );
    return fresh.length;
  }
}

/// What an alert carries so a tap on it knows where to go: the one release it
/// announces, or just the Notifications page when it announces several.
const kReleasesPayload = 'releases';
const _kReleasePayloadPrefix = 'release:';

String releaseAlertPayload(List<MediaContent> releases) => releases.length == 1
    ? '$_kReleasePayloadPrefix${releases.first.id}'
    : kReleasesPayload;

/// The id of the release a [payload] points at; null when it points at the
/// page as a whole.
String? releaseIdOfPayload(String payload) =>
    payload.startsWith(_kReleasePayloadPrefix)
    ? payload.substring(_kReleasePayloadPrefix.length)
    : null;

/// The words of a notification for [releases] (newest first).
({String title, String? body, List<String> lines}) releaseAlertText(
  List<MediaContent> releases,
  AppLocalizations l10n,
) {
  if (releases.length == 1) {
    final release = releases.first;
    final body = [
      release.artistName,
      release.categoryName,
    ].nonNulls.join(' · ');
    return (
      title: release.title,
      body: body.isEmpty ? null : body,
      lines: const [],
    );
  }
  final titles = [for (final release in releases) release.title];
  return (
    title: l10n.newReleasesCount(releases.length),
    body: titles.take(3).join(', '),
    lines: titles.take(5).toList(),
  );
}

/// How the alert for [releases] (newest first) looks: the app's violet on its
/// small icon and name, the time the newest came out rather than the time the
/// phone got round to announcing it, and the title readable on the lock
/// screen. One release comes with its own picture — big when the alert is
/// opened out — and the artist's (or else the same) picture in the round;
/// several come as a list of their titles.
///
/// [picture] and [icon] are the images as bytes, when they could be had.
AndroidNotificationDetails releaseAlertDetails(
  List<MediaContent> releases,
  AppLocalizations l10n, {
  Uint8List? picture,
  Uint8List? icon,
}) {
  final text = releaseAlertText(releases, l10n);
  final single = releases.length == 1;
  final round = single ? (icon ?? picture) : null;

  final StyleInformation? style;
  if (!single) {
    style = InboxStyleInformation(text.lines, contentTitle: text.title);
  } else if (picture != null) {
    style = BigPictureStyleInformation(
      ByteArrayAndroidBitmap(picture),
      largeIcon: round == null ? null : ByteArrayAndroidBitmap(round),
      // The big picture says it all: no second, small one beside the title.
      hideExpandedLargeIcon: true,
      contentTitle: text.title,
      summaryText: text.body,
    );
  } else {
    style = null;
  }

  return AndroidNotificationDetails(
    ReleaseNotificationPresenter._channelId,
    l10n.newReleasesChannel,
    icon: 'ic_stat_radio',
    color: AppColors.brand400,
    largeIcon: round == null ? null : ByteArrayAndroidBitmap(round),
    category: AndroidNotificationCategory.recommendation,
    visibility: NotificationVisibility.public,
    when: releases.first.publishedAt?.millisecondsSinceEpoch,
    styleInformation: style,
  );
}

/// Puts new releases in the Android notification bar.
class ReleaseNotificationPresenter {
  ReleaseNotificationPresenter(
    this._plugin,
    this._l10n, {
    Future<Uint8List?> Function(String? url, {int width}) fetchImage =
        fetchNotificationImage,
  }) : _fetchImage = fetchImage;

  final FlutterLocalNotificationsPlugin _plugin;
  final AppLocalizations _l10n;
  final Future<Uint8List?> Function(String? url, {int width}) _fetchImage;

  static const _channelId = 'com.eradio.ams_e_radio.channel.new_releases';

  /// One id, so a new announcement replaces the last instead of piling up.
  static const _notificationId = 4242;

  Future<void> show(List<MediaContent> releases) async {
    final text = releaseAlertText(releases, _l10n);
    // Pictures only for a single release; a few seconds' wait at most, then it
    // goes out without them.
    final single = releases.length == 1 ? releases.first : null;
    final (picture, icon) = single == null
        ? (null, null)
        : await (
            _fetchImage(single.thumbnailUrl, width: 512),
            _fetchImage(single.artistPhotoUrl, width: 192),
          ).wait;

    await _plugin.show(
      id: _notificationId,
      title: text.title,
      body: text.body,
      // Comes back to the running app when the alert is tapped.
      payload: releaseAlertPayload(releases),
      notificationDetails: NotificationDetails(
        android: releaseAlertDetails(
          releases,
          _l10n,
          picture: picture,
          icon: icon,
        ),
      ),
    );
  }
}

/// What WorkManager runs, in a background isolate of its own — nothing of the
/// running app (its providers, its screen) is there.
@pragma('vm:entry-point')
void releaseAlertsDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_radio'),
        ),
      );
      final language = prefs.getString(kLocaleKey);
      final l10n = lookupAppLocalizations(
        kSupportedLocales.firstWhere(
          (locale) => locale.languageCode == language,
          orElse: () => const Locale('en'),
        ),
      );
      final announced = await ReleaseAlertChecker(
        prefs: prefs,
        fetch: _fetchLatestReleases,
        show: ReleaseNotificationPresenter(plugin, l10n).show,
      ).run();
      debugPrint('New-release check: announced $announced');
    } catch (error) {
      // Nothing to do but wait for the next run — a connection that dropped, a
      // server that is down.
      debugPrint('New-release check failed: $error');
    }
    return true;
  });
}

Future<List<MediaContent>> _fetchLatestReleases() async {
  final res = await ApiClient().get('/media-contents');
  return (res['data'] as List)
      .cast<Map<String, dynamic>>()
      .map(MediaContent.fromJson)
      .toList();
}

/// Asks Android's WorkManager to run the check, and to stop. A no-op anywhere
/// else: on iOS background runs are the system's to grant, and far too
/// unreliable to promise anything with.
class WorkmanagerReleaseAlerts implements ReleaseAlertScheduler {
  WorkmanagerReleaseAlerts(this._prefs);

  final SharedPreferences _prefs;

  static const _taskName = 'new-release-check';

  @override
  Future<void> sync(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final workmanager = Workmanager();
      await workmanager.initialize(releaseAlertsDispatcher);
      if (!enabled) {
        await workmanager.cancelByUniqueName(_taskName);
        return;
      }
      // Whatever is out by now is not news: announce only what comes after.
      if (_prefs.getString(_kAnnouncedKey) == null) {
        await _prefs.setString(
          _kAnnouncedKey,
          DateTime.now().toIso8601String(),
        );
      }
      await workmanager.registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (error) {
      debugPrint('Setting up the new-release check failed: $error');
    }
  }
}
