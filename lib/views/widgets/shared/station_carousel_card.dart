import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/supports/image_decode.dart';
import '../../../core/supports/tap_to_play.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/station.dart';
import '../../../providers/audio_player_controller.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'default_station_art.dart';

const _liveRed = Color(0xFFEF4444);

/// One "On Air" hero card: the station's artwork under a dark fade, a red LIVE
/// badge, its name, and a "Listen Radio" play control that reflects the
/// player's state for this station.
class StationCarouselCard extends ConsumerWidget {
  const StationCarouselCard({
    super.key,
    required this.station,
    required this.width,
  });

  final Station station;
  final double width;

  /// Width ÷ height, so the row can size itself from the card width alone.
  static const aspectRatio = 1.73;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;
    final playback = ref.watch(audioPlayerControllerProvider);
    final isCurrent = playback.item?.id == 'station:${station.id}';
    final isPlaying = isCurrent && playback.status == PlaybackStatus.playing;
    final isLoading = isCurrent && playback.status == PlaybackStatus.loading;
    final coverUrl = station.coverUrl;

    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl != null)
                CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: imageDecodeWidth(
                    context,
                    width,
                    width / aspectRatio,
                  ),
                  fadeInDuration: Duration.zero,
                  errorWidget: (context, url, error) =>
                      const DefaultStationArt(),
                )
              else
                const DefaultStationArt(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.35, 1],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _liveRed,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '• ${l10n.live.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 60,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                          ),
                          child: isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.listenRadio,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Icon(Icons.equalizer_rounded, color: primary, size: 28),
              ),
              // Last, so the ripple and taps cover the whole card.
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => tapToPlay(
                      context,
                      ref,
                      playId: 'station:${station.id}',
                      onTap: () {
                        final controller = ref.read(
                          audioPlayerControllerProvider.notifier,
                        );
                        if (isCurrent) {
                          controller.togglePlayPause();
                        } else {
                          controller.play(NowPlayingItem.fromStation(station));
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
