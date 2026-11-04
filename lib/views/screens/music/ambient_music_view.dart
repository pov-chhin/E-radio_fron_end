import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_colors.dart';
import '../../themes/theme_ext.dart';
import '../../themes/dark_theme.dart';
import '../../themes/light_theme.dart';
import '../../../data/models/tag.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/retry_view.dart';
import '../../../providers/shell_background_provider.dart';
import '../../widgets/shared/filter_pill.dart';
import '../../widgets/shared/media_content_tile.dart';
import '../../widgets/shared/see_all_header.dart';
import '../../widgets/music/ambient_hero.dart';
import '../../widgets/music/ambient_moods.dart';
import '../../widgets/music/ambient_palette.dart';

/// The Ambient Music page: deep blue, "All" and the moods as pills, a big
/// banner for the chosen one and its songs beneath. A mood's page takes the
/// background colour of its card picture (from the database), so the two always
/// match; a light picture gets dark text. [initialTagSlug] is the mood
/// the page opens on (the card that was tapped); without one — "See All" —
/// it opens on All, every mood's songs together.
class AmbientMusicView extends ConsumerStatefulWidget {
  const AmbientMusicView({super.key, this.initialTagSlug});

  final String? initialTagSlug;

  @override
  ConsumerState<AmbientMusicView> createState() => _AmbientMusicViewState();
}

class _AmbientMusicViewState extends ConsumerState<AmbientMusicView> {
  /// The id of the "All" pill — not a tag's, which are numbers.
  static const _allId = 'all';

  /// Above this relative luminance a page is light enough for dark text. Set so
  /// the mid-tone moods (gold, olive, lavender) keep their white text.
  static const _lightPageLuminance = .5;

  String? _tagId;
  late final ShellBackground _shell = ref.read(
    shellBackgroundProvider.notifier,
  );

  @override
  void dispose() {
    // Hand the shell its own color back (after this frame — the tree is
    // still being torn down).
    final shell = _shell;
    Future.microtask(() => shell.set(null));
    super.dispose();
  }

  /// Swiping the banner or the songs moves to the next pill (swipe left) or
  /// the previous one (swipe right) — All, then the moods in order.
  void _swipe(DragEndDetails details, List<String> ids, String? current) {
    final velocity = details.primaryVelocity ?? 0;
    if (current == null || velocity.abs() < 300) return;
    final index = ids.indexOf(current) + (velocity < 0 ? 1 : -1);
    if (index < 0 || index >= ids.length) return;
    setState(() => _tagId = ids[index]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tree = ref.watch(tagsProvider);
    final ambient = AmbientMoods.ambientOf(tree.asData?.value ?? const <Tag>[]);
    final moods = AmbientMoods.moodsOf(ambient);
    // All, unless a mood was picked — or the page was opened on one.
    final showAll =
        _tagId == _allId || (_tagId == null && widget.initialTagSlug == null);
    final selected = showAll
        ? null
        : moods.where((tag) => tag.id == _tagId).firstOrNull ??
              moods
                  .where((tag) => tag.slug == widget.initialTagSlug)
                  .firstOrNull ??
              moods.firstOrNull;
    final selectedId = showAll ? _allId : selected?.id;

    // The background follows the selected mood's card picture: its own
    // background colour, read off the picture. The mood's fixed colour stands
    // in until that's read (or when the mood has no picture, or it won't load).
    final cardUrl = selected?.imageUrl;
    final fromCard = cardUrl == null
        ? null
        : ref.watch(ambientCardColorProvider(cardUrl)).asData?.value;
    final background =
        fromCard ??
        AmbientMoods.colors[selected?.slug] ??
        AppColors.ambientNavy;
    // White text on all but a clearly light background, which gets dark text
    // (and the light theme, so every widget on the page follows).
    final lightPage = background.computeLuminance() > _lightPageLuminance;
    final base = lightPage ? lightTheme : darkTheme;
    final ink = lightPage ? AppColors.lightInk : const Color(0xFFF8FAFC);
    // The shell's strip around the floating player takes the same color — but
    // only while this page is on screen. Switching tabs keeps it alive
    // offstage (not disposed), so it hands the strip back then, or the other
    // tabs would show this page's color.
    final onScreen = TickerMode.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shell.set(onScreen ? background : null);
    });
    final theme = base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        surface: background,
        onSurface: ink,
        onSurfaceVariant: lightPage
            ? AppColors.lightInkSoft
            : const Color(0xFFCBD5E1),
      ),
    );

    return AnimatedTheme(
      data: theme,
      duration: const Duration(milliseconds: 250),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: lightPage
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SeeAllHeader(title: l10n.catAmbient),
                FilterPillRow(
                  alwaysLight: true,
                  items: [
                    FilterPillItem(id: _allId, label: l10n.filterAll),
                    for (final mood in moods)
                      FilterPillItem(id: mood.id, label: mood.name),
                  ],
                  selectedId: selectedId,
                  onSelected: (id) => setState(() => _tagId = id),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) => _swipe(details, [
                      _allId,
                      for (final mood in moods) mood.id,
                    ], selectedId),
                    child: Column(
                      children: [
                        AmbientHero(
                          color: lightPage ? AppColors.lightInk : Colors.white,
                          title: showAll
                              ? l10n.catAmbient
                              : (selected?.name ?? ''),
                          illustration:
                              AmbientMoods.illustrations[selected?.slug],
                          pictureUrl: selected?.imageUrl,
                        ),
                        Expanded(
                          child: _Songs(
                            tree: tree,
                            // All lists what the Ambient Music tag holds — the
                            // songs of every mood.
                            tag: showAll ? ambient : selected,
                          ),
                        ),
                      ],
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

/// The songs under [tag], newest first: a mood's, or — given the Ambient Music
/// tag itself — all of them. [tag] is null until the tag tree has loaded.
class _Songs extends ConsumerWidget {
  const _Songs({required this.tree, required this.tag});

  final AsyncValue<List<Tag>> tree;
  final Tag? tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mood = tag;

    if (mood == null) {
      return tree.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            RetryView(onRetry: () => ref.invalidate(tagsProvider)),
        data: (_) => Center(
          child: Text(
            l10n.noSongsYet,
            style: TextStyle(color: context.mutedText),
          ),
        ),
      );
    }

    final songs = ref.watch(mediaContentsByTagProvider(mood.id));
    return songs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => RetryView(
        onRetry: () => ref.invalidate(mediaContentsByTagProvider(mood.id)),
      ),
      data: (items) => items.isEmpty
          ? Center(
              child: Text(
                l10n.noSongsYet,
                style: TextStyle(color: context.mutedText),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              itemCount: items.length,
              itemBuilder: (context, index) => MediaContentTile(
                item: items[index],
                queueItems: items,
                byArtist: true,
                gap: 8,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
              ),
            ),
    );
  }
}
