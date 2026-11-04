import '../../core/supports/plain_text_from_html.dart';

class MediaContent {
  const MediaContent({
    required this.id,
    required this.title,
    required this.mediaType,
    this.description,
    this.streamUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.playCount,
    this.categoryName,
    this.categorySlug,
    this.artistName,
    this.artistPhotoUrl,
    this.publishedAt,
  });

  final String id;
  final String title;
  final String mediaType;
  final String? description;
  final String? streamUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final int? playCount;
  final String? categoryName;
  final String? categorySlug;
  final String? artistName;

  /// The artist's picture, when they have one.
  final String? artistPhotoUrl;
  final DateTime? publishedAt;

  factory MediaContent.fromJson(Map<String, dynamic> json) => MediaContent(
    id: json['id'] as String,
    title: json['title'] as String,
    mediaType: json['media_type'] as String,
    // The CMS editor saves HTML; the app shows text.
    description: plainTextFromHtmlOrNull(json['description'] as String?),
    streamUrl: json['stream_url'] as String?,
    thumbnailUrl: json['thumbnail_url'] as String?,
    durationSeconds: json['duration_seconds'] as int?,
    playCount: json['play_count'] as int?,
    categoryName: (json['category'] as Map?)?['name'] as String?,
    categorySlug: (json['category'] as Map?)?['slug'] as String?,
    artistName: json['artist_name'] as String?,
    artistPhotoUrl: json['artist_photo_url'] as String?,
    publishedAt: json['published_at'] != null
        ? DateTime.parse(json['published_at'] as String)
        : null,
  );
}
