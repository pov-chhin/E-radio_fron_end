import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/media_content.dart';
import 'shared_preferences_provider.dart';

const _kSeenKey = 'notifications_seen_at';
const _kHiddenKey = 'notifications_hidden';
const _kFewerKey = 'notifications_fewer';
const _kMutedKey = 'notifications_muted';

/// When the inbox was last opened, as saved — null if it never was. For code
/// that runs outside the app's providers (the background check for new
/// releases) and so reads the saved settings directly.
DateTime? savedNotificationsSeen(SharedPreferences prefs) =>
    DateTime.tryParse(prefs.getString(_kSeenKey) ?? '');

/// What the ⋮ menu on a notification has saved — see [savedNotificationsSeen].
NotificationChoices savedNotificationChoices(SharedPreferences prefs) {
  Set<String> read(String key) =>
      (prefs.getStringList(key) ?? const <String>[]).toSet();
  return NotificationChoices(
    hidden: read(_kHiddenKey),
    fewer: read(_kFewerKey),
    muted: read(_kMutedKey),
  );
}

/// When the inbox was last opened, kept on the device. The inbox is the feed
/// of new releases, so a release is "unread" if it was published after this.
/// A fresh install starts at "now" — nothing already on the server counts as
/// news to someone who has only just arrived.
class NotificationsSeen extends Notifier<DateTime> {
  @override
  DateTime build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = savedNotificationsSeen(prefs);
    if (saved != null) return saved;
    final now = DateTime.now();
    prefs.setString(_kSeenKey, now.toIso8601String());
    return now;
  }

  void markAllSeen() {
    final now = DateTime.now();
    state = now;
    ref
        .read(sharedPreferencesProvider)
        .setString(_kSeenKey, now.toIso8601String());
  }
}

final notificationsSeenProvider = NotifierProvider<NotificationsSeen, DateTime>(
  NotificationsSeen.new,
);

/// What the ⋮ menu on a notification has been used for, kept on the device:
/// single releases hidden, and sources (artists) the person wants fewer
/// notifications from, or none at all.
class NotificationChoices {
  const NotificationChoices({
    this.hidden = const {},
    this.fewer = const {},
    this.muted = const {},
  });

  final Set<String> hidden;
  final Set<String> fewer;
  final Set<String> muted;

  /// The source a release is filed under: its artist, else its category.
  static String? sourceOf(MediaContent item) =>
      item.artistName ?? item.categoryName;

  /// [releases] without the hidden ones and the muted sources'.
  List<MediaContent> visible(List<MediaContent> releases) => [
    for (final item in releases)
      if (!hidden.contains(item.id) && !muted.contains(sourceOf(item))) item,
  ];
}

class NotificationChoicesController extends Notifier<NotificationChoices> {
  @override
  NotificationChoices build() =>
      savedNotificationChoices(ref.read(sharedPreferencesProvider));

  void _save(NotificationChoices next) {
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setStringList(_kHiddenKey, next.hidden.toList());
    prefs.setStringList(_kFewerKey, next.fewer.toList());
    prefs.setStringList(_kMutedKey, next.muted.toList());
  }

  void hide(String id) => _save(
    NotificationChoices(
      hidden: {...state.hidden, id},
      fewer: state.fewer,
      muted: state.muted,
    ),
  );

  void showFewerFrom(String source) => _save(
    NotificationChoices(
      hidden: state.hidden,
      fewer: {...state.fewer, source},
      muted: state.muted,
    ),
  );

  void turnOffAllFrom(String source) => _save(
    NotificationChoices(
      hidden: state.hidden,
      fewer: state.fewer,
      muted: {...state.muted, source},
    ),
  );
}

final notificationChoicesProvider =
    NotifierProvider<NotificationChoicesController, NotificationChoices>(
      NotificationChoicesController.new,
    );

/// How many of [releases] came out since the inbox was last opened — the dot
/// on the bell, ignoring what the person hid or muted. A plain function (not a
/// provider derived from the others): a derived provider rebuilding as a
/// paused Discover tab resumes trips a "markNeedsBuild during build"
/// assertion.
int unreadReleases(
  DateTime seen,
  List<MediaContent> releases, [
  NotificationChoices choices = const NotificationChoices(),
]) => choices
    .visible(releases)
    .where((item) => item.publishedAt?.isAfter(seen) ?? false)
    .length;
