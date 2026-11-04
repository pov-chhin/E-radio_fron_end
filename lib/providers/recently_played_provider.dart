import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';

const _kRecentlyPlayedKey = 'recently_played_station_ids';
const _kRecentlyPlayedAtKey = 'recently_played_at';
const _kMaxRecentlyPlayed = 12;

class RecentlyPlayedAtController extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() {
    final stored = ref
        .read(sharedPreferencesProvider)
        .getString(_kRecentlyPlayedAtKey);
    if (stored == null) return const {};

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is int)
            entry.key as String: DateTime.fromMillisecondsSinceEpoch(
              entry.value as int,
            ),
      };
    } on FormatException {
      return const {};
    }
  }

  /// Records when an item started playing, wherever in the app it was chosen.
  void recordPlayedAt(
    String itemId, {
    required List<String> retainedIds,
    DateTime? at,
  }) {
    final retained = retainedIds.toSet();
    final next = {
      for (final entry in state.entries)
        if (retained.contains(entry.key)) entry.key: entry.value,
      itemId: at ?? DateTime.now(),
    };
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setString(
          _kRecentlyPlayedAtKey,
          jsonEncode({
            for (final entry in next.entries)
              entry.key: entry.value.millisecondsSinceEpoch,
          }),
        );
  }
}

final recentlyPlayedAtProvider =
    NotifierProvider<RecentlyPlayedAtController, Map<String, DateTime>>(
      RecentlyPlayedAtController.new,
    );

class RecentlyPlayedController extends Notifier<List<String>> {
  @override
  List<String> build() {
    return ref
            .read(sharedPreferencesProvider)
            .getStringList(_kRecentlyPlayedKey) ??
        const [];
  }

  void recordPlay(String itemId) {
    final next = [itemId, ...state.where((id) => id != itemId)];
    if (next.length > _kMaxRecentlyPlayed) {
      next.removeRange(_kMaxRecentlyPlayed, next.length);
    }
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_kRecentlyPlayedKey, next);
  }
}

final recentlyPlayedProvider =
    NotifierProvider<RecentlyPlayedController, List<String>>(
      RecentlyPlayedController.new,
    );
