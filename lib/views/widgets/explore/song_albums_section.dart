import 'dart:math' as math;
import '../../../core/supports/tap_to_play.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/category_pages.dart';
import '../../../data/models/artist.dart';
import '../../../data/models/media_content.dart';
import '../../../data/repositories/artist_repository.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../shared/media_content_menu.dart';
import '../shared/media_content_tile.dart';
import '../shared/network_thumbnail.dart';
import 'section_header.dart';

/// "Song": one frosted card per artist with a new release — the artist, and up
/// to three of their newest songs on a translucent panel — side by side in a
/// row that scrolls. Renders nothing while there are no songs.
class SongAlbumsSection extends ConsumerWidget {
  const SongAlbumsSection({super.key, this.songs, this.artists});

  final List<MediaContent>? songs;
  final List<Artist>? artists;

  /// At most this many artists get a card, and this many songs a card lists.
  static const maxAlbums = 6;
  static const songsPerAlbum = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final shownSongs =
        songs ??
        ref.watch(mediaContentsByCategoryProvider('song')).asData?.value;
    if (shownSongs == null || shownSongs.isEmpty) {
      return const SizedBox.shrink();
    }

    final photos = {
      for (final artist
          in artists ??
              ref.watch(popularArtistsProvider('')).asData?.value ??
              const <Artist>[])
        artist.name.toLowerCase(): artist.photoUrl,
    };
    final albums = groupSongsByArtist(shownSongs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.catSong,
          onSeeAll: () => openCategory(context, 'song'),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            // 350 on the design's 390 screen; narrower phones shrink the card
            // so the next one still peeks in.
            final width = math.min(
              _SongAlbumCard.designWidth,
              box.maxWidth - 2 * kExploreGutter,
            );
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: kExploreGutter),
              child: Row(
                children: [
                  for (final (index, album) in albums.indexed) ...[
                    if (index > 0) const SizedBox(width: 12),
                    _SongAlbumCard(
                      width: width,
                      artistName: album.artistName ?? l10n.appTitle,
                      artistPhotoUrl: album.artistName == null
                          ? null
                          : photos[album.artistName!.toLowerCase()],
                      songs: album.songs,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// One artist's newest songs; [artistName] is null for songs with no artist.
typedef SongAlbum = ({String? artistName, List<MediaContent> songs});

/// Groups [songs] (newest first) by artist, keeping the order artists first
/// appear in and at most [SongAlbumsSection.songsPerAlbum] songs each, for at
/// most [SongAlbumsSection.maxAlbums] artists. Songs with no artist share one
/// group.
List<SongAlbum> groupSongsByArtist(List<MediaContent> songs) {
  final groups = <String?, List<MediaContent>>{};
  for (final song in songs) {
    final name = song.artistName?.trim();
    final group = groups.putIfAbsent(
      name == null || name.isEmpty ? null : name,
      () => [],
    );
    if (group.length < SongAlbumsSection.songsPerAlbum) group.add(song);
  }
  return [
    for (final entry in groups.entries.take(SongAlbumsSection.maxAlbums))
      (artistName: entry.key, songs: entry.value),
  ];
}

class _SongAlbumCard extends StatelessWidget {
  const _SongAlbumCard({
    required this.width,
    required this.artistName,
    required this.artistPhotoUrl,
    required this.songs,
  });

  final double width;
  final String artistName;
  final String? artistPhotoUrl;
  final List<MediaContent> songs;

  static const _muted = Color(0xFFCBD5E1);
  static const _onDark = Color(0xFFF8FAFC);
  static const height = 320.0;

  /// The card's width on the design's 390px screen.
  static const designWidth = 350.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cover = songs.first.thumbnailUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The cover, blurred and dimmed, is all the card's background. The
            // blur is baked in rather than computed: the picture is decoded at
            // 48 px and stretched over the card, which is as soft as a Gaussian
            // blur but costs nothing per frame — a live BackdropFilter on every
            // card made the row stutter while scrolling.
            if (cover != null)
              CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                memCacheWidth: 48,
                filterQuality: FilterQuality.high,
                fadeInDuration: Duration.zero,
                errorWidget: (context, url, error) =>
                    const ColoredBox(color: Color(0xFF334155)),
              )
            else
              const ColoredBox(color: Color(0xFF334155)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB35B5B5B), Color(0x4D343434)],
                ),
              ),
            ),
            // The card is a fixed 350 x 320 and its content is sized to fill it
            // exactly (48 header + 24 gap + 216 panel = the 288 inside the
            // padding), so a larger system font would push the header over and
            // overflow. Like the mini player, the card ignores the font-size
            // setting and stays pixel-precise.
            MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        NetworkThumbnail(
                          url: artistPhotoUrl ?? cover,
                          width: 48,
                          height: 48,
                          borderRadius: BorderRadius.circular(200),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.newReleaseFrom.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 14,
                                  height: 18 / 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _onDark,
                                  fontSize: 16,
                                  height: 24 / 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x29FFFFFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              for (final (index, song) in songs.indexed) ...[
                                if (index > 0) const SizedBox(height: 12),
                                _SongRow(song: song, queue: songs),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 56px row on the frosted panel: cover, title, "by artist" and a ⋮.
class _SongRow extends ConsumerWidget {
  const _SongRow({required this.song, required this.queue});

  final MediaContent song;
  final List<MediaContent> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final artist = song.artistName;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => tapToPlay(
        context,
        ref,
        playId: 'media:${song.id}',
        onTap: () => playMediaContent(context, ref, song, queueItems: queue),
      ),
      child: SizedBox(
        // Sized to exactly fit the title and subtitle lines this row gives
        // them; the card it sits in ignores the font-size setting for that.
        height: 56,
        child: Row(
          children: [
            NetworkThumbnail(url: song.thumbnailUrl, width: 56, height: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _SongAlbumCard._onDark,
                      fontSize: 16,
                      height: 24 / 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    artist != null && artist.isNotEmpty
                        ? l10n.byArtist(artist)
                        : song.categoryName ?? song.mediaType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _SongAlbumCard._muted,
                      fontSize: 14,
                      height: 22 / 14,
                    ),
                  ),
                ],
              ),
            ),
            // The popup is anchored to the button, so it gets the button's
            // own context.
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: l10n.moreOptions,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 40,
                ),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: _SongAlbumCard._onDark,
                  size: 24,
                ),
                onPressed: () => showMediaContentMenu(
                  buttonContext,
                  ref,
                  song,
                  queueItems: queue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
