import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/supports/image_decode.dart';
import 'default_station_art.dart';

/// Circular artwork (rounded-square if [cornerRadius] is given) for a station
/// or media-content item, falling back to [DefaultStationArt] when there's no
/// image or it fails to load.
class ArtworkAvatar extends StatelessWidget {
  const ArtworkAvatar({
    super.key,
    required this.imageUrl,
    this.size = 56,
    this.cornerRadius,
  });

  final String? imageUrl;
  final double size;
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final radius = cornerRadius;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius == null ? null : BorderRadius.circular(radius),
      ),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: imageDecodeWidth(context, size, size),
              fadeInDuration: Duration.zero,
              errorWidget: (context, url, error) =>
                  DefaultStationArt(padding: size * 0.2),
            )
          : DefaultStationArt(padding: size * 0.2),
    );
  }
}
