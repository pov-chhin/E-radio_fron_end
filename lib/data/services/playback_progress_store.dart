import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../providers/database_provider.dart';

/// On-device "resume playback" position, keyed by [NowPlayingItem.id].
/// Mirrors Spotify/YouTube-Music semantics: a barely-started or
/// effectively-finished position isn't worth resuming from, so [save]
/// deletes the row instead of persisting it.
class PlaybackProgressStore {
  const PlaybackProgressStore(this._db);

  final Database _db;

  static const _table = 'playback_progress';
  static const _minResumableSeconds = 5;
  static const _endBufferSeconds = 15;

  Future<Duration?> fetch(String itemId) async {
    final rows = await _db.query(
      _table,
      columns: ['position_seconds'],
      where: 'item_id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Duration(seconds: rows.first['position_seconds'] as int);
  }

  Future<void> save(
    String itemId,
    Duration position,
    Duration? duration,
  ) async {
    final positionSeconds = position.inSeconds;
    final durationSeconds = duration?.inSeconds;
    final isFinished =
        positionSeconds < _minResumableSeconds ||
        (durationSeconds != null &&
            positionSeconds >= durationSeconds - _endBufferSeconds);

    if (isFinished) {
      await _db.delete(_table, where: 'item_id = ?', whereArgs: [itemId]);
      return;
    }

    await _db.insert(_table, {
      'item_id': itemId,
      'position_seconds': positionSeconds,
      'duration_seconds': durationSeconds,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

final playbackProgressStoreProvider = Provider<PlaybackProgressStore>(
  (ref) => PlaybackProgressStore(ref.read(databaseProvider)),
);
