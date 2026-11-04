import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/supports/image_decode.dart';
import '../../themes/app_colors.dart';

/// A round artist photo — or, with none, the first letter of the name on a
/// soft circle. [selected] draws the violet ring.
class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.selected = false,
    this.size = 72,
  });

  final String name;
  final String? photoUrl;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = photoUrl;
    final initial = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Text(
          name.isEmpty ? '' : name.characters.first.toUpperCase(),
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: size * .38,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: url == null
                ? initial
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    memCacheWidth: imageDecodeWidth(context, size, size),
                    fadeInDuration: Duration.zero,
                    errorWidget: (context, url, error) => initial,
                  ),
          ),
          if (selected)
            const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.brand400, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
