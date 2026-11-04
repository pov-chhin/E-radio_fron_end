import 'package:flutter/material.dart';

/// Category icons aren't set in the backend yet (icon column is null for
/// every seeded row), so pick one client-side from the known slugs.
IconData categoryIconForSlug(String slug) {
  switch (slug) {
    case 'podcast':
      return Icons.mic_rounded;
    case 'news':
      return Icons.newspaper_rounded;
    case 'health':
      return Icons.favorite_rounded;
    case 'economyfinance':
      return Icons.trending_up_rounded;
    case 'song':
      return Icons.music_note_rounded;
    case 'ambient-music':
      return Icons.spa_rounded;
    default:
      return Icons.category_rounded;
  }
}
