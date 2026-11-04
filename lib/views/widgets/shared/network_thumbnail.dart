import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/supports/image_decode.dart';
import 'default_station_art.dart';

/// A rounded picture from [url], or the default station art when there's none
/// or it can't be loaded.
class NetworkThumbnail extends StatelessWidget {
  const NetworkThumbnail({
    super.key,
    required this.url,
    this.width = 56,
    this.height = 56,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final String? url;
  final double width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final fallback = DefaultStationArt(padding: width * 0.15);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: imageDecodeWidth(context, width, height),
                fadeInDuration: Duration.zero,
                errorWidget: (context, url, error) => fallback,
              )
            : fallback,
      ),
    );
  }
}
