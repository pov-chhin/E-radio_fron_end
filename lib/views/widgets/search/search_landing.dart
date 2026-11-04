import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/category_pages.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/recent_searches_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/theme_ext.dart';

const _icons = 'assets/icons/search';

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// A neutral line icon the artwork draws for the light page; on the dark theme
/// it is re-inked.
Widget _lineIcon(BuildContext context, String name, {double? size}) =>
    SvgPicture.asset(
      '$_icons/$name.svg',
      width: size,
      height: size,
      colorFilter: _isDark(context)
          ? ColorFilter.mode(
              Theme.of(context).colorScheme.onSurfaceVariant,
              BlendMode.srcIn,
            )
          : null,
    );

/// The small ✕ the design draws 8.8px wide inside a 12px box, scaled to
/// [box].
class SearchCloseMark extends StatelessWidget {
  const SearchCloseMark({super.key, this.box = 12});

  final double box;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: _lineIcon(context, 'chip_close', size: box * 8.8 / 12),
      ),
    );
  }
}

/// A section's title: 18 semibold in the design's slate, with an optional
/// picture before it.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.leading});

  final String text;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _isDark(context)
                  ? Theme.of(context).colorScheme.onSurface
                  : const Color(0xFF353E5C),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// What Search shows before anything is typed: the recent searches as chips,
/// the categories to browse as coloured tiles, and what is trending.
/// [onSearch] runs a search for the words that were tapped.
class SearchLanding extends ConsumerWidget {
  const SearchLanding({super.key, required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final recents = ref.watch(recentSearchesProvider);
    final trending = trendingSearchTerms(ref);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        if (recents.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: _SectionTitle(l10n.recentSearches)),
              InkWell(
                onTap: ref.read(recentSearchesProvider.notifier).clear,
                child: Text(
                  l10n.clearAll,
                  style: const TextStyle(
                    color: AppColors.brand400,
                    fontSize: 12,
                    height: 18 / 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final term in recents)
                _RecentChip(
                  term: term,
                  onTap: () => onSearch(term),
                  onRemove: () =>
                      ref.read(recentSearchesProvider.notifier).remove(term),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        _SectionTitle(l10n.browseCategories),
        const SizedBox(height: 12),
        const _CategoryGrid(),
        if (trending.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(
            l10n.trendingSearches,
            leading: SvgPicture.asset(
              '$_icons/flame.svg',
              width: 18,
              height: 18,
            ),
          ),
          const SizedBox(height: 12),
          for (final (index, term) in trending.indexed) ...[
            if (index > 0) const SizedBox(height: 4),
            _TrendingRow(
              rank: index + 1,
              term: term,
              onTap: () => onSearch(term),
            ),
          ],
        ],
      ],
    );
  }
}

/// What is trending to search for: the titles of what is being played most,
/// the first few distinct ones.
List<String> trendingSearchTerms(WidgetRef ref, {int count = 4}) {
  final items =
      ref.watch(trendingMediaContentsProvider).asData?.value ?? const [];
  final seen = <String>{};
  return [
    for (final item in items)
      if (seen.add(item.title.trim().toLowerCase())) item.title.trim(),
  ].take(count).toList();
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.term,
    required this.onTap,
    required this.onRemove,
  });

  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final dark = _isDark(context);

    return Material(
      color: context.raisedCard,
      shape: StadiumBorder(
        side: BorderSide(
          color: dark ? colors.outlineVariant : const Color(0xFFE5E7EB),
          width: .5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flexible, so a long term shortens to fit the line instead of
          // pushing the ✕ off the edge.
          Flexible(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _lineIcon(context, 'clock', size: 14),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        term,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dark
                              ? colors.onSurface
                              : const Color(0xFF374151),
                          fontSize: 14,
                          height: 20 / 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Tooltip(
            message: l10n.removeSearchTerm(term),
            child: InkWell(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
                // As tall as the text line beside it, so the chip is 32.
                child: SizedBox(
                  height: 20,
                  child: const Center(child: SearchCloseMark()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The browse tiles, drawn in two columns whatever their height: each has an
/// icon and a name on a tint, and goes to where that kind of thing lives.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final tiles = [
      _Tile(l10n.interestRadio, 'audio_lines', 0xFFEEF2F6, () {
        context.push('/stations');
      }),
      _Tile(l10n.catPodcast, 'mic', 0xFFF5F3FF, () {
        openCategory(context, 'podcast');
      }),
      _Tile(l10n.catNews, 'newspaper', 0xFFECFDF5, () {
        openCategory(context, 'news');
      }),
      _Tile(l10n.searchSongs, 'music_2', 0xFFFFFBEB, () {
        openCategory(context, 'song');
      }),
      _Tile(l10n.catAmbient, 'cloud_rain', 0xFFFEF2F2, () {
        openCategory(context, 'ambient-music');
      }),
      _Tile(l10n.catHealth, 'heart_pulse', 0xFFF0FDF4, () {
        openCategory(context, 'health');
      }),
      _Tile(l10n.interestEconomy, 'bar_chart', 0xFFEFF6FF, () {
        openCategory(context, 'economyfinance');
      }),
      // Education is a podcast topic, not a category of its own: the Podcasts
      // page has its pill.
      _Tile(l10n.interestEducation, 'book_open', 0xFFFDF2F8, () {
        openCategory(context, 'podcast');
      }),
    ];

    Widget cell(int index) =>
        index < tiles.length ? Expanded(child: tiles[index]) : const Spacer();

    return Column(
      children: [
        for (var row = 0; row < (tiles.length + 1) ~/ 2; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell(row * 2),
              const SizedBox(width: 12),
              cell(row * 2 + 1),
            ],
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.icon, this.tint, this.onTap);

  final String label;
  final String icon;
  final int tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // The pastel tints are for the light page; on the dark one they are laid
    // faintly over the surface.
    final color = _isDark(context)
        ? Color.alphaBlend(Color(tint).withValues(alpha: .12), colors.surface)
        : Color(tint);

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SvgPicture.asset('$_icons/$icon.svg', width: 24, height: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      height: 24 / 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({
    required this.rank,
    required this.term,
    required this.onTap,
  });

  final int rank;
  final String term;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: context.raisedCard,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '#$rank',
                style: const TextStyle(
                  color: AppColors.brand400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  term,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 14,
                    height: 20 / 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SvgPicture.asset(
                '$_icons/chevron_right.svg',
                width: 16,
                height: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search with the bar in focus but nothing typed: the recent searches, one a
/// row — a clock, the words, a ✕ to forget them. A tap searches for them.
class RecentSearchList extends ConsumerWidget {
  const RecentSearchList({super.key, required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final recents = ref.watch(recentSearchesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        for (final term in recents)
          InkWell(
            onTap: () => onSearch(term),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _lineIcon(context, 'clock', size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      term,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 16,
                        height: 24 / 16,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: l10n.removeSearchTerm(term),
                    child: InkResponse(
                      radius: 16,
                      onTap: () => ref
                          .read(recentSearchesProvider.notifier)
                          .remove(term),
                      child: const SearchCloseMark(box: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
