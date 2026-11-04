import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/station.dart';
import '../../../providers/station_provider.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../shared/station_carousel_card.dart';
import 'section_header.dart';

/// "On Air": the live stations as a row of hero cards, with the next card
/// peeking in from the right.
class OnAirSection extends ConsumerWidget {
  const OnAirSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stationsAsync = ref.watch(stationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.onAir,
          icon: Icons.mic_rounded,
          onSeeAll: () => context.push('/stations'),
        ),
        const SizedBox(height: 10),
        stationsAsync.when(
          loading: () => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 140,
            child: _InlineError(
              onRetry: () => ref.read(stationsProvider.notifier).refresh(),
            ),
          ),
          data: (stations) => _StationCarousel(stations: stations),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StationCarousel extends StatelessWidget {
  const _StationCarousel({required this.stations});

  final List<Station> stations;

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(AppLocalizations.of(context)!.noStationsPublished),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Leave a sliver of the next card showing so it's clear the row
        // scrolls; a lone station just fills the width.
        final gutter = stations.length == 1 ? 2 * kExploreGutter : 44.0;
        final cardWidth = math.min(constraints.maxWidth - gutter, 420.0);
        return SizedBox(
          height: cardWidth / StationCarouselCard.aspectRatio,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: kExploreGutter),
            itemCount: stations.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                StationCarouselCard(station: stations[index], width: cardWidth),
          ),
        );
      },
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
