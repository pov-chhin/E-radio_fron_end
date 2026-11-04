import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The width, in pixels, to decode a network picture at when it is shown in a
/// [width] × [height] box with `BoxFit.cover`.
///
/// Covers are stored up to 1280 px wide. Decoded whole, each one holds
/// megabytes of pixels for a tile of a few dozen — which is what makes long
/// lists stutter and fills the image cache. 1.5× the box's longer side keeps
/// even a tall or a wide picture sharp (a picture is never scaled up past its
/// own size).
int imageDecodeWidth(BuildContext context, double width, double height) =>
    (math.max(width, height) * MediaQuery.devicePixelRatioOf(context) * 1.5)
        .round();
