import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/paged_list_notifier.dart';
import '../services/api_client.dart';
import '../models/program.dart';

List<Program> _programsFrom(Map<String, dynamic> res) => (res['data'] as List)
    .cast<Map<String, dynamic>>()
    .map(Program.fromJson)
    .toList();

/// First page (20) of every show with a playable episode, most recently
/// updated first — the Home row and the Podcasts page's "All".
final programsProvider = FutureProvider<List<Program>>((ref) async {
  final client = ref.read(apiClientProvider);
  return _programsFrom(await client.get('/programs'));
});

/// The shows on the topic [tagId] — filed under it, or (for the general ones)
/// with an episode tagged with it or a tag nested in it; decided server-side.
final programsByTagProvider = FutureProvider.family<List<Program>, String>((
  ref,
  tagId,
) async {
  final client = ref.read(apiClientProvider);
  return _programsFrom(await client.get('/programs?tag_id=$tagId'));
});

/// The first page of the shows on [tagId] — every show when it is null.
FutureProvider<List<Program>> programsFirstPage(String? tagId) =>
    tagId == null ? programsProvider : programsByTagProvider(tagId);

/// The shows on a topic ([tagId] null is "All") a page at a time, for the
/// Podcasts page and the Podcast category page.
class PagedProgramsNotifier extends PagedListNotifier<Program> {
  PagedProgramsNotifier(this.tagId);

  final String? tagId;

  @override
  FutureProvider<List<Program>> get firstPage => programsFirstPage(tagId);

  @override
  String pagePath(int page) => tagId == null
      ? '/programs?page=$page'
      : '/programs?tag_id=$tagId&page=$page';

  @override
  Program fromJson(Map<String, dynamic> json) => Program.fromJson(json);

  @override
  Object idOf(Program item) => item.id;
}

final pagedProgramsProvider =
    AsyncNotifierProvider.family<
      PagedProgramsNotifier,
      PagedFeed<Program>,
      String?
    >(PagedProgramsNotifier.new);

/// One show with all its episodes, newest first.
final programProvider = FutureProvider.family<Program, String>((
  ref,
  programId,
) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get('/programs/$programId');
  return Program.fromJson(res['data'] as Map<String, dynamic>);
});

/// The show the episode [episodeId] (the media content's id) belongs to, or null
/// — for now, or for good — if none is known to: a standalone episode, or the
/// shows not loaded (yet).
///
/// An episode does not say which show it is in, so this looks through the
/// shows' own episodes: the list of shows, then each show in full, all asked for
/// at once. It answers as soon as the show that holds the episode has loaded, and
/// a show that fails to load does not hold up the others. What has loaded is
/// kept, so asking about another episode is quick.
final programOfEpisodeProvider = Provider.autoDispose.family<Program?, String>((
  ref,
  episodeId,
) {
  final shows = ref.watch(programsProvider).value ?? const <Program>[];
  for (final show in shows) {
    final program = ref.watch(programProvider(show.id)).value;
    if (program != null && program.episodes.any((e) => e.id == episodeId)) {
      return program;
    }
  }
  return null;
});
