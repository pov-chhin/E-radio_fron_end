import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/station_provider.dart';
import '../models/media_content.dart';
import '../models/program.dart';
import '../models/station.dart';
import '../services/api_client.dart';

/// What a search found, in the three kinds of thing there are to find.
class SearchResults {
  const SearchResults({
    this.stations = const [],
    this.programs = const [],
    this.contents = const [],
  });

  final List<Station> stations;
  final List<Program> programs;

  /// Songs and episodes.
  final List<MediaContent> contents;

  bool get isEmpty => stations.isEmpty && programs.isEmpty && contents.isEmpty;
}

/// Everything matching [query]: stations (the whole list is on the device, so
/// they are matched there — name, description, tags), and shows and
/// songs/episodes (asked of the server, which matches names, titles and
/// artists). A source that can't be reached just contributes nothing, so a
/// slow or failing one doesn't lose the others' results — except the
/// stations, whose failure is the "can't reach the server" case.
final searchResultsProvider = FutureProvider.autoDispose
    .family<SearchResults, String>((ref, query) async {
      final text = query.trim();
      final stations = await ref.watch(stationsProvider.future);
      final client = ref.read(apiClientProvider);
      final encoded = Uri.encodeQueryComponent(text);

      Future<List<T>> fetch<T>(
        String path,
        T Function(Map<String, dynamic>) parse,
      ) async {
        try {
          final res = await client.get(path);
          final data = res is Map ? res['data'] : null;
          if (data is! List) return const [];
          return data.cast<Map<String, dynamic>>().map(parse).toList();
        } on Exception {
          return const [];
        }
      }

      final contents = fetch(
        '/media-contents?q=$encoded&limit=20',
        MediaContent.fromJson,
      );
      final programs = fetch('/programs?q=$encoded', Program.fromJson);

      final needle = text.toLowerCase();
      bool matches(Station station) =>
          station.name.toLowerCase().contains(needle) ||
          (station.description?.toLowerCase().contains(needle) ?? false) ||
          station.tags.any((tag) => tag.toLowerCase().contains(needle));

      return SearchResults(
        stations: stations.where(matches).toList(),
        programs: await programs,
        contents: await contents,
      );
    });
