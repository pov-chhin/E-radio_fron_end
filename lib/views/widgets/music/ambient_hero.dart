import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The picture band at the top of the Ambient Music page. For a mood with a card
/// picture ([pictureUrl], from the database) it is that picture — the name and
/// the illustration are in it, exactly as on the mood's card. Otherwise, and
/// until the picture arrives or if it can't load, the band is drawn: the mood's
/// name in big condensed capitals on the left, an optional illustration on the
/// right, and two soft yellow glows that — as drawn — spill out of the band: one
/// behind the pills above it, one down onto the songs below.
class AmbientHero extends StatelessWidget {
  const AmbientHero({
    super.key,
    required this.title,
    this.illustration,
    this.pictureUrl,
    this.color = Colors.white,
  });

  final String title;

  /// The colour of the drawn name — white, unless the page behind it is a
  /// light one.
  final Color color;

  /// An asset path for the drawn band, or null for one with just the name.
  final String? illustration;

  /// The mood's card picture, or null to draw the band instead.
  final String? pictureUrl;

  static const height = 210.0;

  @override
  Widget build(BuildContext context) {
    final drawn = _DrawnHero(
      title: title,
      illustration: illustration,
      color: color,
    );
    final url = pictureUrl;
    if (url == null) return drawn;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Semantics(
        label: title,
        image: true,
        child: CachedNetworkImage(
          imageUrl: url,
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) => drawn,
          errorWidget: (context, url, error) => drawn,
          imageBuilder: (context, image) => AmbientHeroPicture(image: image),
        ),
      ),
    );
  }
}

/// A card picture filling the band. Its top and bottom edges fade into the page
/// colour, so the band doesn't show as a box where the card's corner colours
/// differ from the page's.
class AmbientHeroPicture extends StatelessWidget {
  const AmbientHeroPicture({super.key, required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00000000),
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x00000000),
        ],
        stops: [0, .08, .8, 1],
      ).createShader(bounds),
      child: Image(
        image: image,
        width: double.infinity,
        height: AmbientHero.height,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// The band drawn by the app: the name, an optional illustration and the glows.
class _DrawnHero extends StatelessWidget {
  const _DrawnHero({
    required this.title,
    required this.illustration,
    required this.color,
  });

  final String title;
  final String? illustration;
  final Color color;

  static const height = AmbientHero.height;

  @override
  Widget build(BuildContext context) {
    final illustration = this.illustration;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final pictureSize = width * .3897;

          // Not clipped: the glows reach past the band on purpose.
          return Stack(
            clipBehavior: Clip.none,
            children: [
              const _GlowLayer(_Glow.lowLeft),
              if (illustration != null)
                Positioned(
                  right: width * .0607,
                  top: (height - pictureSize) / 2,
                  width: pictureSize,
                  height: pictureSize,
                  child: Image.asset(illustration, fit: BoxFit.contain),
                ),
              const _GlowLayer(_Glow.topRight),
              Positioned(
                left: 30.5,
                top: 0,
                bottom: 0,
                width: illustration != null ? width * .5 : width - 61,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.oswald(
                      color: color,
                      fontSize: 40,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One blurred, tilted ellipse, placed the way the design lays it out: a box
/// given by its insets from the band (left/right as a share of its width,
/// top/bottom of its height — negative reaches outside), and an ellipse inside
/// it whose width and height are each the length of a pair of shares of that
/// box's width and height, turned by [rotation] and sheared by [skew] (degrees)
/// about the box's centre.
class _Glow {
  const _Glow({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.widthShare,
    required this.heightShare,
    required this.rotation,
    required this.skew,
    required this.color,
    required this.blur,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final (double, double) widthShare;
  final (double, double) heightShare;
  final double rotation;
  final double skew;
  final Color color;

  /// The Gaussian's standard deviation.
  final double blur;

  /// The faint green wash low on the left, bleeding down past the band. It
  /// sits under the illustration.
  static const lowLeft = _Glow(
    left: -.5534,
    top: .1381,
    right: .5115,
    bottom: -.7195,
    widthShare: (.879657, -.274209),
    heightShare: (.120343, .725791),
    rotation: -14.29,
    skew: -2.82,
    color: Color(0x0FEDF838),
    blur: 25,
  );

  /// The brighter pale-yellow one in the top-right corner, reaching up behind
  /// the pills. It sits over the illustration.
  static const topRight = _Glow(
    left: .7824,
    top: -.3819,
    right: -.1535,
    bottom: .6181,
    widthShare: (.586364, -.544167),
    heightShare: (.413636, .455833),
    rotation: -45.8,
    skew: -6.49,
    color: Color(0x80FAFFA7),
    blur: 50,
  );

  void paint(Canvas canvas, Size size) {
    final boxWidth = size.width * (1 - left - right);
    final boxHeight = size.height * (1 - top - bottom);
    final centre = Offset(
      size.width * left + boxWidth / 2,
      size.height * top + boxHeight / 2,
    );
    double length((double, double) share) => math.sqrt(
      math.pow(share.$1 * boxWidth, 2) + math.pow(share.$2 * boxHeight, 2),
    );

    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..transform(
        (Matrix4.rotationZ(
          rotation * math.pi / 180,
        )..multiply(Matrix4.skewX(skew * math.pi / 180))).storage,
      )
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: length(widthShare),
          height: length(heightShare),
        ),
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      )
      ..restore();
  }
}

/// Fills the band and paints one [_Glow] — which may reach outside it.
class _GlowLayer extends StatelessWidget {
  const _GlowLayer(this.glow);

  final _Glow glow;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(child: CustomPaint(painter: _GlowPainter(glow))),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.glow);

  final _Glow glow;

  @override
  void paint(Canvas canvas, Size size) => glow.paint(canvas, size);

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => oldDelegate.glow != glow;
}
