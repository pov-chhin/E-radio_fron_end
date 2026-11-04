import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/category_pages.dart';
import '../../../core/supports/image_decode.dart';
import '../../../data/models/tag.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../themes/app_colors.dart';
import '../music/ambient_moods.dart';
import 'section_header.dart';

/// The two-row Ambient Music carousel from the Discover design.
///
/// It holds every mood of the Ambient Music tag — the same ones the Ambient
/// Music page has as pills — so a mood added on the server shows up here too.
/// A mood's card is the picture uploaded for it in the admin and served by the
/// database. While it loads, or for a mood without one (or if it can't load),
/// the card is drawn from the mood's colour and illustration. Until the tags
/// themselves have loaded (or if they can't) the five original moods stand in.
class CategoriesSection extends ConsumerWidget {
  const CategoriesSection({super.key, this.tags});

  final List<Tag>? tags;

  static const _fallback = [
    _AmbientTile(name: 'Working', slug: 'working'),
    _AmbientTile(name: 'Relaxing', slug: 'lobbylounge'),
    _AmbientTile(name: 'Studying', slug: 'studying'),
    _AmbientTile(name: 'Yoga', slug: 'yoga'),
    _AmbientTile(name: 'Sports', slug: 'Sports'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tree = tags ?? ref.watch(tagsProvider).asData?.value ?? const <Tag>[];
    final moods = AmbientMoods.moodsOf(AmbientMoods.ambientOf(tree));
    final tiles = moods.isEmpty
        ? _fallback
        : [
            for (final mood in moods)
              _AmbientTile(
                name: mood.name,
                slug: mood.slug,
                imageUrl: mood.imageUrl,
              ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.catAmbient,
          onSeeAll: () => openCategory(context, AmbientMoods.slug),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kExploreGutter),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 154,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: tiles.length,
            itemBuilder: (context, index) {
              final tile = tiles[index];
              return Semantics(
                button: true,
                label: tile.name,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go('/music/ambient?tag=${tile.slug}'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _AmbientCard(tile),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _AmbientTile {
  const _AmbientTile({required this.name, required this.slug, this.imageUrl});
  final String name;
  final String slug;

  /// The picture uploaded for the mood, if any.
  final String? imageUrl;
}

/// One 154×74 card: the picture uploaded for the mood; until it arrives, or if
/// it can't load, one drawn from the mood's colour.
class _AmbientCard extends StatelessWidget {
  const _AmbientCard(this.tile);

  final _AmbientTile tile;

  @override
  Widget build(BuildContext context) {
    final url = tile.imageUrl;
    final drawn = _DrawnCard(tile);
    if (url == null) return drawn;

    return CachedNetworkImage(
      imageUrl: url,
      width: 154,
      height: 74,
      fit: BoxFit.cover,
      memCacheWidth: imageDecodeWidth(context, 154, 74),
      fadeInDuration: Duration.zero,
      placeholder: (context, url) => drawn,
      errorWidget: (context, url, error) => drawn,
    );
  }
}

/// The card the app draws itself: the mood's colour with its name in big
/// condensed capitals and its illustration.
class _DrawnCard extends StatelessWidget {
  const _DrawnCard(this.tile);

  final _AmbientTile tile;

  @override
  Widget build(BuildContext context) {
    final color = AmbientMoods.colors[tile.slug] ?? AppColors.ambientNavy;
    final illustration = AmbientMoods.illustrations[tile.slug];
    return SizedBox(
      width: 154,
      height: 74,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, .3)!],
          ),
        ),
        child: Stack(
          children: [
            if (illustration != null)
              Positioned(
                right: 8,
                top: 4,
                bottom: 4,
                child: Image.asset(illustration, fit: BoxFit.contain),
              ),
            Positioned(
              left: 14,
              top: 0,
              bottom: 0,
              width: illustration != null ? 70 : 126,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tile.name.toUpperCase(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
