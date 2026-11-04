import '../../data/models/now_playing_item.dart';
import '../../data/models/station.dart';

/// Whether [item] is one of the stations, rather than a song, an episode or the
/// like.
bool isStationItem(NowPlayingItem item) => item.id.startsWith('station:');

/// The station [step] places from [current] among [stations] — 1 for the one
/// after it, -1 for the one before — as the list has them, going round at either
/// end. Null while the list has not loaded, if [current] is not in it, or if it
/// has no other station to go to.
NowPlayingItem? adjacentStation(
  List<Station>? stations,
  NowPlayingItem current,
  int step,
) {
  final items = [
    for (final station in stations ?? const <Station>[])
      NowPlayingItem.fromStation(station),
  ];
  final at = items.indexWhere((item) => item.id == current.id);
  if (at < 0 || items.length < 2) return null;
  return items[(at + step) % items.length];
}
