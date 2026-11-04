import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/artist.dart';
import '../../../data/models/media_content.dart';
import '../../../data/models/tag.dart';
import '../../../data/repositories/artist_repository.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../themes/theme_ext.dart';
import '../../widgets/shared/filter_pill.dart';
import '../../widgets/shared/media_content_tile.dart';
import 'music_tags.dart';
import '../../widgets/music/genres_section.dart';
import '../../widgets/music/music_section_title.dart';
import '../../widgets/music/popular_artists_section.dart';

/// The Music page: a big title, "All / Local / International" pills, the
/// popular artists, the genres and the popular songs. Picking a pill, an artist
/// or a genre narrows the songs — an artist and a genre together give that
/// artist's songs in that genre. (Ambient Music is not here; it lives on
/// Discover.)
class MusicView extends ConsumerStatefulWidget {
  const MusicView({super.key});

  @override
  ConsumerState<MusicView> createState() => _MusicViewState();
}

class _MusicViewState extends ConsumerState<MusicView> {
  /// null is "All"; otherwise the tab tag's slug ('local' / 'international').
  String? _tab;

  /// The picked genre's name, shared by the Local and International branches.
  String? _genre;
  String? _artistId;

  /// The filter tabs a swipe steps through, in the order of the pills.
  static const _tabs = <String?>[null, 'local', 'international'];

  void _swipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 300) return;
    final index = _tabs.indexOf(_tab) + (velocity < 0 ? 1 : -1);
    if (index < 0 || index >= _tabs.length) return;
    setState(() {
      _tab = _tabs[index];
      _artistId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    final music = MusicTags.from(
      ref.watch(tagsProvider).asData?.value ?? const <Tag>[],
    );
    final scope = music.scope(_tab);
    final genres = music.genreNames(scope);
    final genre = genres.contains(_genre) ? _genre : null;
    final tabIds = _tab == null
        ? const <String>[]
        : [for (final tag in scope) tag.id];
    final songTagIds = genre == null ? tabIds : music.genreIds(scope, genre);

    final artists =
        ref.watch(popularArtistsProvider(tabIds.join(','))).asData?.value ??
        const <Artist>[];
    final songsFilter = (tagIds: songTagIds.join(','), artistId: _artistId);
    final songs = ref.watch(popularSongsProvider(songsFilter));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(popularArtistsProvider);
            ref.invalidate(popularSongsProvider);
            await ref.read(popularSongsProvider(songsFilter).future);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _swipe,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Text(
                    l10n.music,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 28,
                      height: 36 / 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilterPillRow(
                  items: [
                    FilterPillItem(id: null, label: l10n.filterAll),
                    FilterPillItem(id: 'local', label: l10n.tabLocal),
                    FilterPillItem(
                      id: 'international',
                      label: l10n.tabInternational,
                    ),
                  ],
                  selectedId: _tab,
                  onSelected: (id) => setState(() {
                    _tab = id;
                    _artistId = null;
                  }),
                ),
                if (artists.isNotEmpty)
                  PopularArtistsSection(
                    artists: artists,
                    selectedId: _artistId,
                    onSelected: (id) => setState(() => _artistId = id),
                  ),
                if (genres.isNotEmpty)
                  GenresSection(
                    genres: genres,
                    selected: genre,
                    onSelected: (name) => setState(() => _genre = name),
                  ),
                _SongsSection(
                  songs: songs,
                  onRetry: () =>
                      ref.invalidate(popularSongsProvider(songsFilter)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Popular Songs": the rows, most-played first.
class _SongsSection extends StatelessWidget {
  const _SongsSection({required this.songs, required this.onRetry});

  final AsyncValue<List<MediaContent>> songs;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MusicSectionTitle(l10n.popularSongs),
          const SizedBox(height: 10),
          songs.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Center(
              child: TextButton(onPressed: onRetry, child: Text(l10n.retry)),
            ),
            data: (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.noSongsYet,
                        style: TextStyle(color: context.mutedText),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final item in items)
                        MediaContentTile(
                          item: item,
                          queueItems: items,
                          byArtist: true,
                          gap: 8,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
