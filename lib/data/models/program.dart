import '../../core/supports/plain_text_from_html.dart';
import 'media_content.dart';

/// A show (podcast): a cover, a description and the episodes that belong to
/// it. The list endpoint leaves [episodes] empty; the detail one fills it,
/// newest first. The description is plain text — the API sends the HTML the
/// CMS editor saved, and it is turned into text here.
class Program {
  const Program({
    required this.id,
    required this.name,
    this.description,
    this.coverImageUrl,
    this.categoryName,
    this.hostName,
    this.episodeCount,
    this.episodes = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String? coverImageUrl;
  final String? categoryName;

  /// Shows have no host of their own; this is the newest episode's artist.
  final String? hostName;
  final int? episodeCount;
  final List<MediaContent> episodes;

  factory Program.fromJson(Map<String, dynamic> json) => Program(
    id: json['id'] as String,
    name: json['name'] as String,
    description: plainTextFromHtmlOrNull(json['description'] as String?),
    coverImageUrl: json['cover_image_url'] as String?,
    // The podcast type (Health, Economy/Finance, …) when the show has one, else its category.
    categoryName:
        ((json['type'] ?? json['category']) as Map?)?['name'] as String?,
    hostName: json['host_name'] as String?,
    episodeCount: json['episode_count'] as int?,
    episodes: (json['episodes'] as List? ?? const [])
        .map((e) => MediaContent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
