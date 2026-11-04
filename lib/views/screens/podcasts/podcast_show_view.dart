import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../themes/app_colors.dart';
import '../../../data/services/api_exception.dart';
import '../../../core/supports/coming_soon.dart';
import '../../themes/theme_ext.dart';
import '../../../data/models/program.dart';
import '../../../data/repositories/program_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/retry_view.dart';
import '../../widgets/shared/content_unavailable_view.dart';
import '../../widgets/shared/default_station_art.dart';
import '../../widgets/shared/media_content_tile.dart';
import 'program_byline.dart';
import '../../widgets/podcasts/episode_row.dart';

/// One show: a cover header with its name and host, "Play Latest" and
/// "Follow", the description, and every episode, newest first.
class PodcastShowView extends ConsumerWidget {
  const PodcastShowView({super.key, required this.programId});

  final String programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider(programId));

    return program.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      // A show that was removed (or never existed) gets its own page.
      error: (error, _) => error is ApiException && error.statusCode == 404
          ? const ContentUnavailableView()
          : Scaffold(
              appBar: AppBar(),
              body: RetryView(
                onRetry: () => ref.invalidate(programProvider(programId)),
              ),
            ),
      data: (program) => _ShowBody(program: program),
    );
  }
}

class _ShowBody extends ConsumerWidget {
  const _ShowBody({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final episodes = program.episodes;
    final description = program.description;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _ArtworkHeader(program: program)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _PillButton(
                        icon: Icons.play_arrow_outlined,
                        label: l10n.playLatest,
                        filled: true,
                        onPressed: episodes.isEmpty
                            ? null
                            : () => playMediaContent(
                                context,
                                ref,
                                episodes.first,
                                queueItems: episodes,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PillButton(
                        icon: Icons.add_rounded,
                        label: l10n.follow,
                        filled: false,
                        onPressed: () => showComingSoon(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (description != null && description.trim().isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _Description(text: description.trim()),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  l10n.allEpisodes,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 20,
                    height: 24 / 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (episodes.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Center(
                    child: Text(
                      l10n.noEpisodesYet,
                      style: TextStyle(color: context.mutedText),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: episodes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) => EpisodeRow(
                    number: index + 1,
                    episode: episodes[index],
                    queueItems: episodes,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// The 220px picture at the top, fading to dark so the name reads over it,
/// with the frosted back and ⋮ buttons above it.
class _ArtworkHeader extends StatelessWidget {
  const _ArtworkHeader({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final byline = programByline(l10n, program);
    final coverUrl = program.coverImageUrl;

    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: Duration.zero,
                  errorWidget: (context, url, error) =>
                      const DefaultStationArt(padding: 56),
                )
              : const DefaultStationArt(padding: 56),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xFF111827)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GlassButton(
                      icon: Icons.arrow_back_rounded,
                      iconSize: 24,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/explore'),
                    ),
                    _GlassButton(
                      icon: Icons.more_vert_rounded,
                      iconSize: 20,
                      tooltip: l10n.moreOptions,
                      onTap: () => _showShowMenu(context, program),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  program.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 28 / 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (byline != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    byline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 16,
                      height: 1.5,
                    ),
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

void _showShowMenu(BuildContext context, Program program) {
  final l10n = AppLocalizations.of(context)!;
  showModalBottomSheet<void>(
    context: context,
    // On the root navigator, so it slides up over the player and tab bar the
    // shell keeps at the bottom rather than stopping above them.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListTile(
        leading: const Icon(Icons.share_rounded),
        title: Text(l10n.share),
        onTap: () {
          Navigator.of(sheetContext).pop();
          SharePlus.instance.share(ShareParams(text: program.name));
        },
      ),
    ),
  );
}

/// A round button of frosted glass — 20% white over a light blur — for the
/// picture's corners.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.iconSize,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
          child: Material(
            color: Colors.white.withValues(alpha: .2),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, size: iconSize, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 37px pill: solid violet ([filled]) or a plain outline. A null
/// [onPressed] dims it.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? Colors.white : context.mutedText;

    return Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: Material(
        color: filled ? AppColors.brand400 : Colors.transparent,
        shape: StadiumBorder(
          side: filled
              ? BorderSide.none
              : BorderSide(color: context.outline, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 37,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

/// The show's description, cut to three lines; tap to read it all.
class _Description extends StatefulWidget {
  const _Description({required this.text});

  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: double.infinity,
          child: Text(
            widget.text,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: context.mutedText,
              fontSize: 14,
              height: 20 / 14,
            ),
          ),
        ),
      ),
    );
  }
}
