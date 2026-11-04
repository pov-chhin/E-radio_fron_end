/// Mirrors the backend's RadioSceaperStation (via StationResource): a flat,
/// uncategorized live stream. The API only ever returns published stations,
/// so every Station here is guaranteed to have a working stream_url.
class Station {
  const Station({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.description,
    this.coverUrl,
    this.bitrate,
    this.votes,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String streamUrl;
  final String? description;
  final String? coverUrl;
  final int? bitrate;
  final int? votes;
  final List<String> tags;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  factory Station.fromJson(Map<String, dynamic> json) => Station(
    id: json['id'] as String,
    name: json['name'] as String,
    streamUrl: json['stream_url'] as String,
    description: json['description'] as String?,
    coverUrl: json['cover_url'] as String?,
    bitrate: json['bitrate'] as int?,
    votes: json['votes'] as int?,
    tags: (json['tags'] as List?)?.cast<String>() ?? const [],
  );
}
