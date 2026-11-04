import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supports/require_sign_in.dart';
import '../../../data/models/media_content.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../data/repositories/program_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../providers/favorites_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/theme_ext.dart';
import '../podcasts/episode_row.dart';
import 'player_actions_menu.dart';

/// The podcast category: the only one with episodes. A podcast episode is
/// listed with the others of its show — its program.
const podcastCategory = 'podcast';

/// The categories that get only the card about the item, with no list of
/// others, no Episodes button and no popup.
const aboutOnlyCategories = {'news', 'health', 'economyfinance', 'song'};

/// Whether [item] gets anything under the controls: the card about it — a
/// podcast episode, an item of news, health or economy/finance, or a song; not
/// a station or the rest.
bool hasEpisodeSections(NowPlayingItem item) =>
    !item.isLive &&
    (hasEpisodeList(item) || aboutOnlyCategories.contains(item.categorySlug));

/// Whether [item] also gets the list of the other episodes of its show, the
/// Episodes button and the popup: a podcast episode only.
bool hasEpisodeList(NowPlayingItem item) =>
    !item.isLive && item.categorySlug == podcastCategory;

/// The episodes of the show — the podcast program — that the episode with the
/// media content id [episodeId] belongs to, as things to play (those that can),
/// newest first. Empty if it is in no show (a standalone episode) or its show is
/// not known yet. Whatever the play list or the category holds does not matter:
/// the episodes come from the show.
final showEpisodesProvider = Provider.autoDispose
    .family<List<NowPlayingItem>, String>((ref, episodeId) {
      final program = ref.watch(programOfEpisodeProvider(episodeId));
      return [
        for (final episode in program?.episodes ?? const <MediaContent>[])
          ?NowPlayingItem.fromMediaContent(episode),
      ];
    });

/// The episodes of the show besides the one playing — empty while the show is
/// being found, if it cannot be, or when the playing one is alone in it. The key
/// is the playing episode's media content id.
final otherEpisodesProvider = Provider.autoDispose
    .family<List<NowPlayingItem>, String>((ref, episodeId) {
      return [
        for (final episode in ref.watch(showEpisodesProvider(episodeId)))
          if (episode.contentId != episodeId) episode,
      ];
    });

/// The other episodes of what is playing, or none if it is not a podcast
/// episode (nothing is asked of the API for those).
List<NowPlayingItem> _othersOf(WidgetRef ref, NowPlayingItem? item) {
  if (item == null || !hasEpisodeList(item)) return const [];
  return ref.watch(otherEpisodesProvider(item.contentId));
}

/// What an episode played from the lists plays with: its show's list, so next
/// and previous step through it — with the one playing first if the show does
/// not list it.
List<NowPlayingItem> _showQueue(WidgetRef ref) {
  final current = ref.read(audioPlayerControllerProvider).item;
  if (current == null) return const [];
  final all = ref.read(showEpisodesProvider(current.contentId));
  return [if (!all.any((e) => e.id == current.id)) current, ...all];
}

/// How many of the other episodes the card under the controls lists; "see more"
/// opens the rest.
const _previewCount = 4;

void _play(WidgetRef ref, NowPlayingItem episode) {
  final queue = _showQueue(ref);
  ref
      .read(audioPlayerControllerProvider.notifier)
      .play(
        episode,
        queue: queue,
        queueIndex: queue.indexWhere((q) => q.id == episode.id),
      );
}

/// What lies under the controls of a podcast, news, health, economy/finance or
/// song on Now Playing: the card about it — its title, how long it runs and how
/// old it is, a heart, and what it is about. A podcast episode has more: the
/// heading "Details" over the card with the "Episodes" button level with it,
/// and, when its show has other episodes, the "Episode" card with the first few
/// of them. Both "Episodes" and "see more" open all of them in a popup.
class EpisodeSections extends ConsumerWidget {
  const EpisodeSections({
    super.key,
    required this.item,
    this.bottomPadding = 24,
  });

  final NowPlayingItem item;
  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final others = _othersOf(ref, item);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasEpisodeList(item)) ...[
            // A podcast has its heading, with the Episodes button level with it.
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.episodeDetails,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (others.isNotEmpty)
                  _EpisodesPill(
                    label: l10n.episodesButton,
                    onTap: () => showEpisodesSheet(context),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _AboutCard(item: item),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 16),
            _EpisodeCard(others: others),
          ],
        ],
      ),
    );
  }
}

/// A white (or, in the dark theme, raised) rounded card with a hairline edge.
class _Card extends StatelessWidget {
  const _Card({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.raisedCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outline),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

class _EpisodesPill extends StatelessWidget {
  const _EpisodesPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('episodesPill'),
      color: colors.onSurface.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.format_list_bulleted_rounded,
                size: 14,
                color: colors.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.item});

  final NowPlayingItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final meta = episodeMeta(
      context,
      durationSeconds: item.durationSeconds,
      publishedAt: item.publishedAt,
    );
    final description = item.description?.trim();

    return _Card(
      key: const Key('aboutEpisodeCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _Heart(item: item),
            ],
          ),
          if (meta != null) ...[
            const SizedBox(height: 2),
            Text(
              meta,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The heart: favorite this episode (signed-in only), the same as the one over
/// the picture.
class _Heart extends ConsumerWidget {
  const _Heart({required this.item});

  final NowPlayingItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isFavorite = ref.watch(favoritesProvider).contains(item.id);
    return IconButton(
      tooltip: isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 32),
      icon: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isFavorite ? AppColors.primary : context.mutedText,
        size: 22,
      ),
      onPressed: () => requireSignIn(
        context,
        ref,
        () => ref.read(favoritesProvider.notifier).toggle(item.id),
      ),
    );
  }
}

class _EpisodeCard extends ConsumerWidget {
  const _EpisodeCard({required this.others});

  final List<NowPlayingItem> others;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final shown = others.take(_previewCount).toList();

    return _Card(
      key: const Key('episodeCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.episodeSection,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Always there, as in the design: it opens the popup.
              InkWell(
                key: const Key('episodeSeeMore'),
                onTap: () => showEpisodesSheet(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    l10n.seeMore,
                    style: const TextStyle(
                      color: AppColors.brand400,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final episode in shown)
            _EpisodeLine(episode: episode, onTap: () => _play(ref, episode)),
        ],
      ),
    );
  }
}

/// One episode: its title over what it is filed under, and a ⋮.
class _EpisodeLine extends ConsumerWidget {
  const _EpisodeLine({required this.episode, required this.onTap});

  final NowPlayingItem episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final subtitle = episode.subtitle;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.mutedText,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),
            // The popup hangs from the button, so it gets the button's own
            // context.
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: l10n.moreOptions,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 36,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: colors.onSurface,
                  size: 20,
                ),
                onPressed: () => showQueueItemMenu(
                  buttonContext,
                  ref,
                  episode,
                  queue: _showQueue(ref),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The popup of every other episode, sliding up over the player. Tapping one
/// closes it and plays that one.
Future<void> showEpisodesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // On the root navigator, so it slides up over the player and tab bar the
    // shell keeps at the bottom rather than stopping above them.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .8,
    ),
    builder: (_) => const _EpisodesSheet(),
  );
}

class _EpisodesSheet extends ConsumerWidget {
  const _EpisodesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final item = ref.watch(audioPlayerControllerProvider.select((p) => p.item));
    final others = _othersOf(ref, item);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              l10n.episodeSection,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              key: const Key('episodesSheetList'),
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 14, 16),
              itemCount: others.length,
              itemBuilder: (context, index) {
                final episode = others[index];
                return _EpisodeLine(
                  episode: episode,
                  onTap: () {
                    Navigator.of(context).pop();
                    _play(ref, episode);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
