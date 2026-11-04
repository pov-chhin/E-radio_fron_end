import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/media_content_repository.dart';
import '../../../data/models/media_content.dart';
import '../shared/media_content_tile.dart';
import 'section_header.dart';

/// A titled preview of media content ("Trending Programs", "New Releases"):
/// rows of three, and when there are more than three the columns sit side by
/// side and swipe, with the next column peeking in from the right. Renders
/// nothing while there's no data (loading, failed or empty) rather than an
/// empty shell — the catalog is still sparse, so most of these are expected to
/// be quiet.
class MediaColumnsSection extends ConsumerStatefulWidget {
  const MediaColumnsSection({
    super.key,
    required this.title,
    required this.provider,
    required this.seeAllPath,
    this.items,
  });

  final String title;
  final MediaContentListProvider provider;
  final String seeAllPath;
  final List<MediaContent>? items;

  @override
  ConsumerState<MediaColumnsSection> createState() =>
      _MediaColumnsSectionState();
}

class _MediaColumnsSectionState extends ConsumerState<MediaColumnsSection> {
  static const _rowsPerColumn = 3;
  static const _maxItems = 9;

  static const _rowHeight = 56.0;
  static const _rowGap = 12.0;

  /// Just under 1, so the neighbouring column shows a sliver. Pages are
  /// centred, so the 5% left over on each side is the page margin (about
  /// [kExploreGutter] on a phone) — the first column lines up with the
  /// section title, and the last one sits flush with the right margin.
  final _controller = PageController(viewportFraction: 0.913);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.items ?? ref.watch(widget.provider).asData?.value;
    if (all == null || all.isEmpty) return const SizedBox.shrink();
    final items = all.take(_maxItems).toList();

    final columns = [
      for (var i = 0; i < items.length; i += _rowsPerColumn)
        items.sublist(i, math.min(i + _rowsPerColumn, items.length)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: widget.title,
          onSeeAll: () => context.push(widget.seeAllPath),
        ),
        const SizedBox(height: 16),
        if (columns.length == 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kExploreGutter),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  SizedBox(
                    height: _rowHeight,
                    // Sized to exactly fit the title and subtitle lines this
                    // row gives them; a larger system font would push that
                    // over and overflow the fixed row height, so — like the
                    // mini player — this ignores the font-size setting and
                    // stays pixel-precise.
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.noScaling),
                      child: MediaContentTile(
                        item: items[i],
                        queueItems: items,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (i != items.length - 1) const SizedBox(height: _rowGap),
                ],
              ],
            ),
          )
        else
          SizedBox(
            height:
                _rowsPerColumn * _rowHeight + (_rowsPerColumn - 1) * _rowGap,
            child: PageView.builder(
              controller: _controller,
              itemCount: columns.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    for (var i = 0; i < columns[index].length; i++) ...[
                      SizedBox(
                        height: _rowHeight,
                        child: MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: TextScaler.noScaling),
                          child: MediaContentTile(
                            item: columns[index][i],
                            queueItems: items,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (i != columns[index].length - 1)
                        const SizedBox(height: _rowGap),
                    ],
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
