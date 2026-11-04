class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    slug: json['slug'] as String,
    description: json['description'] as String?,
    icon: json['icon'] as String?,
  );
}
