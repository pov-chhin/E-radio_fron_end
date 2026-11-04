import 'embed_source.dart';
import 'media_content.dart';
import 'station.dart';

/// What's actually loaded in the single shared AudioPlayer — a Station or a
/// MediaContent (song/podcast), normalized to the fields the player UI needs.
/// A UI-side view model, not an API resource itself — mirrors 988score-app's
/// `data/model_view/` (e.g. `league_detail/tab_item.dart`).
/// [id] is prefixed by source so station and media-content ids (both plain
/// numeric strings from different tables) never collide in recently-played.
class NowPlayingItem {
  const NowPlayingItem({
    required this.id,
    required this.title,
    required this.streamUrl,
    required this.isLive,
    this.subtitle,
    this.artworkUrl,
    this.publishedAt,
    this.playCount,
    this.categorySlug,
    this.description,
    this.durationSeconds,
  });

  final String id;
  final String title;
  final String streamUrl;

  /// The 'station:'/'media:' id prefix split into what the backend's
  /// comment/bookmark endpoints expect: a short type alias + numeric id.
  String get contentType => id.split(':').first;
  String get contentId => id.split(':').last;

  EmbedSource? get _videoLink =>
      isLive ? null : EmbedSource.tryParse(streamUrl);

  /// Set when [streamUrl] is a YouTube or Facebook video page. That can't be
  /// turned into audio for the shared AudioPlayer, so it plays in the site's own
  /// embedded player on the Now Playing page.
  EmbedSource? get embed => _videoLink;

  /// A live station has no meaningful timeline to seek — on-demand
  /// media content does.
  final bool isLive;
  final String? subtitle;
  final String? artworkUrl;

  /// Real publish timestamp for on-demand content — never fabricated, so
  /// null (and hidden) for anything that doesn't actually have one.
  final DateTime? publishedAt;

  /// How many times it has been played — the "views". Null for stations.
  final int? playCount;

  /// The slug of the category it is filed under (`song`, `podcast`, …); null
  /// for a station, or when the API did not say.
  final String? categorySlug;

  /// What the episode is about, as plain text — "About the episode" on Now
  /// Playing. Null for a station, or when there is none.
  final String? description;

  /// How long it runs, as the API says; null for a station or when unknown.
  final int? durationSeconds;

  /// A song (or ambient track): the music player — shuffle, repeat, skip — is
  /// for these, where a podcast episode keeps its ±10 s buttons.
  bool get isSong => categorySlug == 'song' || categorySlug == 'ambient-music';

  NowPlayingItem withPlayCount(int value) => NowPlayingItem(
    id: id,
    title: title,
    streamUrl: streamUrl,
    isLive: isLive,
    subtitle: subtitle,
    artworkUrl: artworkUrl,
    publishedAt: publishedAt,
    playCount: value,
    categorySlug: categorySlug,
    description: description,
    durationSeconds: durationSeconds,
  );

  NowPlayingItem withStreamUrl(String value) => NowPlayingItem(
    id: id,
    title: title,
    streamUrl: value,
    isLive: isLive,
    subtitle: subtitle,
    artworkUrl: artworkUrl,
    publishedAt: publishedAt,
    playCount: playCount,
    categorySlug: categorySlug,
    description: description,
    durationSeconds: durationSeconds,
  );

  factory NowPlayingItem.fromStation(Station station) => NowPlayingItem(
    id: 'station:${station.id}',
    title: station.name,
    streamUrl: station.streamUrl,
    isLive: true,
    subtitle: station.tags.isNotEmpty ? station.tags.first : null,
    artworkUrl: station.coverUrl,
  );

  /// Null if the content has no playable stream (e.g. an article, or a
  /// song/podcast with nothing uploaded yet) — callers should check this
  /// before offering a play control.
  static NowPlayingItem? fromMediaContent(MediaContent item) {
    final streamUrl = item.streamUrl;
    if (streamUrl == null) return null;
    final subtitle = [item.categoryName, item.artistName].nonNulls.join(' · ');
    return NowPlayingItem(
      id: 'media:${item.id}',
      title: item.title,
      streamUrl: streamUrl,
      isLive: false,
      subtitle: subtitle.isEmpty ? null : subtitle,
      artworkUrl: item.thumbnailUrl,
      publishedAt: item.publishedAt,
      playCount: item.playCount,
      categorySlug: item.categorySlug,
      description: item.description,
      durationSeconds: item.durationSeconds,
    );
  }
}
