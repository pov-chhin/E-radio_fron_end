import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/tag.dart';
import '../../../data/repositories/media_content_repository.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/retry_view.dart';
import '../../widgets/shared/media_content_tile.dart';
import '../../widgets/category/tag_chip_row.dart';

class TagView extends ConsumerWidget {
  const TagView({super.key, required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final contentAsync = ref.watch(mediaContentsByTagProvider(tag.id));

    return Scaffold(
      appBar: AppBar(title: Text(tag.name)),
      body: Column(
        children: [
          TagChipRow(children: tag.children),
          Expanded(
            child: contentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => RetryView(
                onRetry: () =>
                    ref.invalidate(mediaContentsByTagProvider(tag.id)),
              ),
              data: (items) => items.isEmpty
                  ? Center(child: Text(l10n.noContentYet))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => MediaContentTile(
                        item: items[index],
                        queueItems: items,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
