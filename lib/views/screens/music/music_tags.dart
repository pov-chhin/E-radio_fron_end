import '../../../data/models/tag.dart';

/// The Song branch of the tag tree as the Music page reads it: "Local" and
/// "International", each holding a "Genre" node whose children are the genres
/// (Hip-hop/Rap, Rock, …). The same genre names exist under both.
class MusicTags {
  const MusicTags({this.local, this.international});

  final Tag? local;
  final Tag? international;

  factory MusicTags.from(List<Tag> tree) {
    final song = _child(tree, 'song')?.children;
    return MusicTags(
      local: _child(song, 'local'),
      international: _child(song, 'international'),
    );
  }

  /// The tags a tab covers: its own, or both for "All" ([tab] null).
  List<Tag> scope(String? tab) => switch (tab) {
    'local' => [?local],
    'international' => [?international],
    _ => [?local, ?international],
  };

  /// The genre tags under [scope], in the order they were created.
  List<Tag> genresIn(List<Tag> scope) {
    final genres =
        [for (final tag in scope) ...?_child(tag.children, 'genre')?.children]
          ..sort(
            (a, b) =>
                (int.tryParse(a.id) ?? 0).compareTo(int.tryParse(b.id) ?? 0),
          );
    return genres;
  }

  /// The genre names under [scope], each once.
  List<String> genreNames(List<Tag> scope) =>
      {for (final genre in genresIn(scope)) genre.name}.toList();

  /// The ids of every genre called [name] under [scope] — one per branch.
  List<String> genreIds(List<Tag> scope, String name) => [
    for (final genre in genresIn(scope))
      if (genre.name == name) genre.id,
  ];

  static Tag? _child(List<Tag>? tags, String slug) {
    for (final tag in tags ?? const <Tag>[]) {
      if (tag.slug == slug) return tag;
    }
    return null;
  }
}
