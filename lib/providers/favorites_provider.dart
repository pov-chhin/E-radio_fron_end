import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';

const _kFavoritesKey = 'favorite_station_ids';

/// Ids are prefixed by source ('station:'/'media:', matching NowPlayingItem.id)
/// so a station and a media item that happen to share a numeric id never
/// collide. Ids stored before media-content favoriting existed have no
/// prefix — they're always stations, so they're migrated in place on load.
class FavoritesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getStringList(_kFavoritesKey);
    if (stored == null) return <String>{};

    var migratedAny = false;
    final migrated = stored.map((id) {
      if (id.contains(':')) return id;
      migratedAny = true;
      return 'station:$id';
    }).toSet();

    if (migratedAny) prefs.setStringList(_kFavoritesKey, migrated.toList());
    return migrated;
  }

  void toggle(String id) {
    final next = {...state};
    if (!next.remove(id)) {
      next.add(id);
    }
    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_kFavoritesKey, next.toList());
  }

  bool isFavorite(String id) => state.contains(id);
}

final favoritesProvider = NotifierProvider<FavoritesController, Set<String>>(
  FavoritesController.new,
);
