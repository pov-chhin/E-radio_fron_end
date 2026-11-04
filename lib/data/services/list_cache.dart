import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How many items of a list are kept on the device — enough to fill the top
/// of the Discover screen, not the whole catalogue.
const kTopCacheLimit = 10;

/// How long a stored top stays good for. Past this the list is treated as not
/// there — a spinner beats showing a screen that is weeks out of date. Within
/// it the stored copy is still shown at once, and refreshed behind the scenes.
const kCacheMaxAge = Duration(days: 7);

/// The top of a few lists, kept as the API's own JSON so the next launch can
/// draw them before the network has answered. Reads are synchronous (the
/// preferences are already in memory), so a cached list is there on the very
/// first frame.
class ListCache {
  ListCache(this._prefs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  /// Bump when the stored shape changes so old entries are ignored.
  static const _prefix = 'list_cache.v1.';

  /// When each entry was last confirmed against the server. Paths start with
  /// `/`, so these keys can never collide with the entries above.
  static const _stampPrefix = 'list_cache.v1.stamp.';

  /// An unchanged list is re-stamped no more often than this, so a launch that
  /// finds nothing new still doesn't touch the disk.
  static const _restampAfter = Duration(days: 1);

  /// The items stored under [key], or null when there are none, they are older
  /// than [kCacheMaxAge], or they can't be read — a bad entry is treated as a
  /// miss, never an error. An entry with no stamp (left by an earlier version
  /// of the app) is still shown, and gets one on its next write.
  List<Map<String, dynamic>>? read(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null) return null;
    final age = _age(key);
    if (age != null && age > kCacheMaxAge) return null;
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// Keeps the first [kTopCacheLimit] of [items] under [key]. Skips the disk
  /// when that is what is already there, which is nearly always.
  Future<void> write(String key, List<Map<String, dynamic>> items) async {
    final encoded = jsonEncode(items.take(kTopCacheLimit).toList());
    final unchanged = _prefs.getString('$_prefix$key') == encoded;
    final age = _age(key);
    if (unchanged && age != null && age < _restampAfter) return;

    if (!unchanged) await _prefs.setString('$_prefix$key', encoded);
    await _prefs.setInt('$_stampPrefix$key', _now().millisecondsSinceEpoch);
  }

  Duration? _age(String key) {
    final stamp = _prefs.getInt('$_stampPrefix$key');
    if (stamp == null) return null;
    return _now().difference(DateTime.fromMillisecondsSinceEpoch(stamp));
  }
}
