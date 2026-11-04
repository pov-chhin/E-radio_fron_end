import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import '../shared/network_thumbnail.dart';

/// A show's cover drawn three times, each a little lower and more solid than
/// the one behind it, so the picture reads as a small stack of cards. A
/// [badge] ("6 EP") sits in a white pill on the front picture's bottom-right
/// corner.
class PodcastArtworkStack extends StatelessWidget {
  const PodcastArtworkStack({super.key, required this.url, this.badge});

  final String? url;
  final String? badge;

  /// The picture's own height, plus the 6px the two cards behind it peek out.
  static const height = 164.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          Widget layer({
            required double top,
            required double pictureHeight,
            required double opacity,
            required double radius,
          }) => Positioned(
            top: top,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: opacity,
              child: NetworkThumbnail(
                url: url,
                width: box.maxWidth,
                height: pictureHeight,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          );

          return Stack(
            children: [
              layer(top: 0, pictureHeight: 160, opacity: .4, radius: 23),
              layer(top: 3, pictureHeight: 160, opacity: .6, radius: 17),
              layer(top: 6, pictureHeight: 158, opacity: 1, radius: 12),
              if (badge != null)
                Positioned(right: 8, bottom: 8, child: _Badge(text: badge!)),
            ],
          );
        },
      ),
    );
  }
}

/// A small white pill with dark lettering that reads on any cover, light or
/// dark, in either theme. Fixed-size lettering: it sits on a picture of fixed
/// size, so it ignores the system font-size setting.
class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          maxLines: 1,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            color: AppColors.lightInk,
            fontSize: 11,
            height: 16 / 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
