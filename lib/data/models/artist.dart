/// A music artist as the Music page lists them: a name and, when uploaded, a
/// photo.
class Artist {
  const Artist({required this.id, required this.name, this.photoUrl});

  final String id;
  final String name;
  final String? photoUrl;

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
    id: json['id'] as String,
    name: json['name'] as String,
    photoUrl: json['photo_url'] as String?,
  );
}
