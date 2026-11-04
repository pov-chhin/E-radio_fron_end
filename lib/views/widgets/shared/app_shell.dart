import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/home_repository.dart';
import '../../../data/repositories/artist_repository.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../data/repositories/program_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../providers/shell_background_provider.dart';
import '../../../providers/station_provider.dart';
import '../player/mini_player.dart';
import 'app_navigation_bar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _warmMusic();
    });
  }

  /// The Music tab is only built when it is first opened, which left it on a
  /// spinner for a few round trips to the server. Starting its first lists now,
  /// behind Discover, means they are usually there by the time it is opened.
  /// (Discover already loads the artists.)
  void _warmMusic() {
    ref.read(tagsProvider);
    ref.read(popularSongsProvider((tagIds: '', artistId: null)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshCatalog();
  }

  void _refreshCatalog() {
    ref.invalidate(homeProvider);
    ref.invalidate(newReleaseMediaContentsProvider);
    ref.invalidate(trendingMediaContentsProvider);
    ref.invalidate(trendingProgramMediaContentsProvider);
    ref.invalidate(mediaContentsByCategoryProvider);
    ref.invalidate(mediaContentsByTagProvider);
    ref.invalidate(pagedMediaContentsProvider);
    ref.invalidate(mediaContentsByIdsProvider);
    ref.invalidate(programsProvider);
    ref.invalidate(programsByTagProvider);
    ref.invalidate(pagedProgramsProvider);
    ref.invalidate(programProvider);
    ref.invalidate(popularArtistsProvider);
    ref.invalidate(popularSongsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(stationsProvider);
    // The tags carry the Ambient Music cards' pictures, which the admin can
    // change at any time. While they reload the old list stays on screen, so
    // nothing blinks.
    ref.invalidate(tagsProvider);
    // Invalidating drops the lists of a Music tab that was never opened, so
    // start them again rather than leaving the next visit cold.
    _warmMusic();
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;

    // Every page draws its own top — Discover its greeting, the See All pages
    // a back arrow and a title — so the shell is only the player and the bar.
    return Scaffold(
      backgroundColor: ref.watch(shellBackgroundProvider),
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          AppNavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onSelected: (index) {
              if (index == 0) _refreshCatalog();
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
          ),
        ],
      ),
    );
  }
}
