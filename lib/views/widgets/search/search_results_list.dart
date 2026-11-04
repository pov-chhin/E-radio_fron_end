import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/category_pages.dart';
import '../../../data/models/category.dart';
import '../../../data/models/program.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/search_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/recent_searches_provider.dart';
import '../../../providers/station_provider.dart';
import '../../screens/podcasts/program_byline.dart';
import '../../themes/theme_ext.dart';
import '../shared/dots_menu.dart';
import '../shared/filter_pill.dart';
import '../shared/media_content_tile.dart';
import '../shared/network_thumbnail.dart';
import '../shared/station_row.dart';
import 'search_landing.dart';

/// The words worth offering while [typed] is being typed: what was searched
/// for before, then what is trending, that contain it — never the words
/// themselves — at most [count].
List<String> searchSuggestions(
  String typed,
  List<String> recents,
  List<String> trending, {
  int count = 4,
}) {
  final needle = typed.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  final seen = <String>{needle};
  return [
    for (final term in [...recents, ...trending])
      if (term.toLowerCase().contains(needle) &&
          seen.add(term.trim().toLowerCase()))
        term,
  ].take(count).toList();
}

/// What matched [query]: stations, shows and songs/episodes, one under the
/// other. While the words are still being typed ([submitted] false) it is one
/// list, with suggestions for finishing them on top; once they are sent in it
/// is grouped under "Radio Stations", "Podcasts" and "Songs & Episodes". With
/// nothing found it says so and offers the categories.
class SearchResultsList extends ConsumerWidget {
  const SearchResultsList({
    super.key,
    required this.query,
    required this.typed,
    required this.submitted,
    required this.onSearch,
    required this.onFill,
  });

  /// What the results are for (it trails [typed] by a moment while typing).
  final String query;

  /// What is in the bar now, for the suggestions.
  final String typed;
  final bool submitted;

  /// Searches for the words that were tapped.
  final ValueChanged<String> onSearch;

  /// Puts the words in the bar to carry on from, without searching.
  final ValueChanged<String> onFill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final results = ref.watch(searchResultsProvider(query));

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: TextButton(
          onPressed: () {
            ref.invalidate(searchResultsProvider(query));
            ref.read(stationsProvider.notifier).refresh();
          },
          child: Text(l10n.retry),
        ),
      ),
      data: (found) {
        final suggestions = submitted
            ? const <String>[]
            : searchSuggestions(
                typed,
                ref.watch(recentSearchesProvider),
                trendingSearchTerms(ref),
              );

        Widget header(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.onSurface
                  : const Color(0xFF353E5C),
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

        return ListView(
          padding: const EdgeInsets.only(top: 10, bottom: 24),
          children: [
            for (final term in suggestions)
              _SuggestionRow(
                term: term,
                onTap: () => onSearch(term),
                onFill: () => onFill(term),
              ),
            if (suggestions.isNotEmpty && !found.isEmpty)
              const SizedBox(height: 12),
            if (found.isEmpty)
              const SearchNoResults()
            else ...[
              if (found.stations.isNotEmpty) ...[
                if (submitted) header(l10n.searchRadioStations),
                for (final station in found.stations)
                  StationRow(station: station),
              ],
              if (found.programs.isNotEmpty) ...[
                if (submitted) header(l10n.podcasts),
                for (final program in found.programs)
                  _ProgramRow(program: program),
              ],
              if (found.contents.isNotEmpty) ...[
                if (submitted) header(l10n.searchSongsAndEpisodes),
                for (final item in found.contents)
                  MediaContentTile(item: item, queueItems: found.contents),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// One way to finish the words: a magnifier, the words in grey, and an ↖ that
/// drops them into the bar. A tap on the row searches for them.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.term,
    required this.onTap,
    required this.onFill,
  });

  final String term;
  final VoidCallback onTap;
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/search/suggestion_search.svg',
              width: 34,
              height: 34,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                term,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.mutedText,
                  fontSize: 16,
                  height: 24 / 16,
                ),
              ),
            ),
            Tooltip(
              message: l10n.useSuggestion(term),
              child: InkResponse(
                radius: 20,
                onTap: onFill,
                child: SvgPicture.asset(
                  'assets/icons/search/arrow_up_left.svg',
                  width: 16,
                  height: 16,
                  colorFilter: dark
                      ? ColorFilter.mode(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                          BlendMode.srcIn,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A show, as a 56px row like the others: its cover, the name over "by host •
/// category", and a ⋮. A tap opens it.
class _ProgramRow extends StatelessWidget {
  const _ProgramRow({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final byline = programByline(l10n, program);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(
            // Not the whole row, so the ⋮ keeps its own tap.
            child: InkWell(
              onTap: () => context.go('/podcasts/${program.id}'),
              child: Row(
                children: [
                  NetworkThumbnail(url: program.coverImageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          program.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (byline != null)
                          Text(
                            byline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: 14,
                              height: 20 / 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: l10n.moreOptions,
              constraints: const BoxConstraints.tightFor(width: 24, height: 40),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert_rounded,
                color: colors.onSurface,
                size: 24,
              ),
              onPressed: () => showDotsMenu(buttonContext, [
                DotsMenuItem(
                  icon: Icons.share_rounded,
                  label: l10n.share,
                  onTap: () =>
                      SharePlus.instance.share(ShareParams(text: program.name)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// "No results found — Try another keyword or explore popular categories
/// below", and the categories below it.
class SearchNoResults extends ConsumerWidget {
  const SearchNoResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? const <Category>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          Text(
            l10n.noResultsTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noResultsMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.mutedText,
              fontSize: 14,
              height: 20 / 14,
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  FilterPill(
                    label: category.name,
                    height: 38,
                    selected: false,
                    onTap: () => openCategory(context, category.slug),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
