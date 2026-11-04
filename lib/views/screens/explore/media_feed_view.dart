import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/media_content_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/retry_view.dart';
import '../../widgets/shared/media_content_tile.dart';
import '../../widgets/shared/see_all_header.dart';

/// A See All list of media rows under a centred title (Trending Programs, New
/// Releases).
class MediaFeedView extends ConsumerWidget {
  const MediaFeedView({super.key, required this.title, required this.provider});

  final String title;
  final MediaContentListProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(provider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SeeAllHeader(title: title),
            Expanded(
              child: itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    RetryView(onRetry: () => ref.invalidate(provider)),
                data: (items) => RefreshIndicator(
                  onRefresh: () => ref.read(provider.notifier).refresh(),
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 320,
                              child: Center(child: Text(l10n.noContentYet)),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          // The first row sits 10px under the header.
                          padding: const EdgeInsets.only(top: 4, bottom: 24),
                          itemCount: items.length,
                          itemBuilder: (context, index) => MediaContentTile(
                            item: items[index],
                            queueItems: items,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 23,
                              vertical: 6,
                            ),
                          ),
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
