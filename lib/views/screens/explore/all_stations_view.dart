import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/supports/coming_soon.dart';
import '../../../data/models/station.dart';
import '../../../providers/station_provider.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/shared/retry_view.dart';
import '../../widgets/shared/see_all_header.dart';
import '../../widgets/shared/station_carousel_card.dart';
import '../../widgets/shared/station_row.dart';

/// On Air's See All: the station on air as a hero card — the one playing, else
/// the first — over the list of every station.
class AllStationsView extends ConsumerWidget {
  const AllStationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final stationsAsync = ref.watch(stationsProvider);
    final playingId = ref.watch(
      audioPlayerControllerProvider.select((state) => state.item?.id),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SeeAllHeader(
              title: l10n.onAirNow,
              trailing: InkResponse(
                radius: 20,
                onTap: () => showComingSoon(context),
                child: Semantics(
                  button: true,
                  label: l10n.schedule,
                  excludeSemantics: true,
                  child: SvgPicture.asset(
                    'assets/icons/calendar_days.svg',
                    width: 20,
                    height: 20,
                    colorFilter: Theme.of(context).brightness == Brightness.dark
                        ? ColorFilter.mode(colors.onSurface, BlendMode.srcIn)
                        : null,
                  ),
                ),
              ),
            ),
            Expanded(
              child: stationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => RetryView(
                  onRetry: () => ref.read(stationsProvider.notifier).refresh(),
                ),
                data: (stations) => stations.isEmpty
                    ? Center(child: Text(l10n.noStationsPublished))
                    : _Body(
                        stations: stations,
                        hero:
                            stations
                                .where((s) => 'station:${s.id}' == playingId)
                                .firstOrNull ??
                            stations.first,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.stations, required this.hero});

  final List<Station> stations;
  final Station hero;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(
            builder: (context, box) => Align(
              alignment: Alignment.centerLeft,
              // 346 on the 390 screen: the page gutter, less the 4px the
              // design leaves at the right.
              child: StationCarouselCard(
                station: hero,
                width: box.maxWidth - 4,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 6),
          child: Text(
            l10n.allStations,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 20,
              height: 24 / 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final station in stations) StationRow(station: station),
      ],
    );
  }
}
