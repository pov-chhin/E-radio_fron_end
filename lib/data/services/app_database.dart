import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The on-device SQLite database — currently just playback resume state, but
/// the natural home for any future purely-local, per-install data.
class AppDatabase {
  static const _fileName = 'e_radio.db';
  static const _version = 1;

  static Future<Database> open() async {
    // sqflite only ships native support for Android/iOS/macOS; desktop needs
    // the FFI-backed sqlite3 factory instead.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _fileName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE playback_progress (
            item_id TEXT PRIMARY KEY,
            position_seconds INTEGER NOT NULL,
            duration_seconds INTEGER,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }
}
