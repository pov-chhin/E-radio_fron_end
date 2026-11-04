class Tag {
  const Tag({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.children = const [],
  });

  final String id;
  final String name;
  final String slug;

  /// The picture uploaded for this tag in the admin (an Ambient Music mood's
  /// card), or null when it has none.
  final String? imageUrl;
  final List<Tag> children;

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    imageUrl: json['image_url'] as String?,
    children: (json['children'] as List? ?? const [])
        .map((c) => Tag.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}
