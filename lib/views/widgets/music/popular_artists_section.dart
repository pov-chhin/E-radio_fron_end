import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../../../data/models/artist.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'artist_avatar.dart';
import 'music_section_title.dart';

/// "Popular Artists": round photos with the name beneath, five to a row and
/// two rows at most, on a block that scrolls sideways when it is wider than the
/// screen. Tapping an artist picks them (a ring and a violet name); tapping
/// again lets go.
class PopularArtistsSection extends StatelessWidget {
  const PopularArtistsSection({
    super.key,
    required this.artists,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Artist> artists;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  static const _perRow = 5;
  static const _maxRows = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shown = artists.take(_perRow * _maxRows).toList();
    final rows = [
      for (var i = 0; i < shown.length; i += _perRow)
        shown.sublist(i, math.min(i + _perRow, shown.length)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: MusicSectionTitle(l10n.popularArtists),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var r = 0; r < rows.length; r++) ...[
                  if (r > 0) const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < rows[r].length; c++) ...[
                        if (c > 0) const SizedBox(width: 12),
                        _ArtistCell(
                          artist: rows[r][c],
                          selected: rows[r][c].id == selectedId,
                          onTap: () => onSelected(
                            rows[r][c].id == selectedId ? null : rows[r][c].id,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistCell extends StatelessWidget {
  const _ArtistCell({
    required this.artist,
    required this.selected,
    required this.onTap,
  });

  final Artist artist;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              ArtistAvatar(
                name: artist.name,
                photoUrl: artist.photoUrl,
                selected: selected,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 68,
                child: Text(
                  artist.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.brand400 : colors.onSurface,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
