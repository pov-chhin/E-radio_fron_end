import 'package:flutter/painting.dart';

import 'now_playing_item.dart';

/// The two Apsara stations whose player shows what is on air and the day's
/// programs (their schedule lives on the AMS program site, not in our own API).
enum ApsaraStation {
  fm97(
    name: 'Apsara FM97',
    frequency: '97.0',
    tagline: 'វិទ្យុសំឡេងយុវជន ៩៧',
    streamFolder: 'radio97',
    parentId: 104,
    hueFrom: 355,
    hueTo: 232,
    accent: Color(0xFFD62B3A),
    accentOnDark: Color(0xFFD62B3A),
  ),
  fm99(
    name: 'Apsara FM99',
    frequency: '99.0',
    tagline: 'វិទ្យុសំឡេងមាតុភូមិ ៩៩',
    streamFolder: 'radio99',
    parentId: 125,
    hueFrom: 205,
    hueTo: 232,
    accent: Color(0xFF2A5BD7),
    // The logo's blue is too dim for small text on the dark page.
    accentOnDark: Color(0xFF6C9BFF),
  );

  const ApsaraStation({
    required this.name,
    required this.frequency,
    required this.tagline,
    required this.streamFolder,
    required this.parentId,
    required this.hueFrom,
    required this.hueTo,
    required this.accent,
    required this.accentOnDark,
  });

  final String name;

  /// In MHz, as the station says it.
  final String frequency;
  final String tagline;

  /// The folder its live stream is served from (`…/radio97/stream/…`).
  final String streamFolder;

  /// The id of the station's own entry among the program site's programs; every
  /// show of the station is filed under it.
  final int parentId;

  /// The two ends of the colour sweep of the picture, as hues (0 to 360).
  final double hueFrom;
  final double hueTo;

  final Color accent;
  final Color accentOnDark;

  /// Which Apsara station [item] is, or null for anything else — a different
  /// station, or a song or podcast. Matched on the stream (not the name) so a
  /// test or relay channel that merely mentions FM97 is left alone.
  static ApsaraStation? fromItem(NowPlayingItem item) {
    if (!item.isLive) return null;
    final path = Uri.tryParse(item.streamUrl)?.pathSegments ?? const <String>[];
    for (final station in values) {
      if (path.contains(station.streamFolder)) return station;
    }
    return null;
  }
}
