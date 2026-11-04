import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'default_station_art.dart';

/// Artwork for the player's portrait frame: the picture at the frame's full
/// width and its own height, centered, so a wide station logo shows whole
/// instead of being cut to its middle. A blurred, darkened copy of it fills the
/// space above and below; a picture taller than the frame is trimmed top and
/// bottom.
class FullArtwork extends StatelessWidget {
  const FullArtwork({super.key, required this.url});

  final String url;

  /// Width ÷ height of the frame.
  static const aspectRatio = 3 / 4;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),
        ),
        const ColoredBox(color: Color(0x66000000)),
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.fitWidth,
          fadeInDuration: Duration.zero,
          errorWidget: (context, url, error) =>
              const DefaultStationArt(padding: 64),
        ),
      ],
    );
  }
}
