import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// Two or three bright colours for the playing bars, picked from a cover
/// picture's raw RGBA [pixels]: the colours that most take the eye in it, and
/// not its greys, blacks and whites. Null when it has no such colours (a black
/// and white logo, a mostly-transparent one) — the bars then keep their own.
///
/// Each colour is brightened to a mid, clear tone, so it shows on a white page
/// and on the dark pill on Now Playing alike. A picture with one dominant colour
/// gets that colour and its two neighbours on the colour wheel.
List<Color>? coverBarColorsOf(Uint8List pixels, int width, int height) {
  final count = width * height;
  if (count < 1 || pixels.length < count * 4) return null;

  const hues = 12;
  const hueWidth = 360 / hues;
  final weight = List.filled(hues, 0.0);
  final red = List.filled(hues, 0.0);
  final green = List.filled(hues, 0.0);
  final blue = List.filled(hues, 0.0);
  var colourful = 0;

  for (var i = 0; i < count; i++) {
    final at = i * 4;
    if (pixels[at + 3] < 200) continue;
    final hsv = HSVColor.fromColor(
      Color.fromARGB(255, pixels[at], pixels[at + 1], pixels[at + 2]),
    );
    if (hsv.saturation < .3 || hsv.value < .25) continue;
    colourful++;
    // The brighter and purer a pixel, the more it counts.
    final w = hsv.saturation * hsv.value;
    final hue = hsv.hue ~/ hueWidth % hues;
    weight[hue] += w;
    red[hue] += pixels[at] * w;
    green[hue] += pixels[at + 1] * w;
    blue[hue] += pixels[at + 2] * w;
  }
  if (colourful < count * .04) return null;

  // Strongest first, skipping a hue next to one already taken: they would read
  // as one colour.
  final byWeight = [for (var i = 0; i < hues; i++) i]
    ..sort((a, b) => weight[b].compareTo(weight[a]));
  final strongest = weight[byWeight.first];
  final picked = <int>[];
  for (final hue in byWeight) {
    if (picked.length == 3 || weight[hue] < strongest * .15) break;
    final apart = picked.every((other) {
      final gap = (hue - other).abs();
      return (gap < hues - gap ? gap : hues - gap) >= 2;
    });
    if (apart) picked.add(hue);
  }
  picked.sort();

  final colours = [
    for (final hue in picked)
      _clear(
        Color.fromARGB(
          255,
          (red[hue] / weight[hue]).round(),
          (green[hue] / weight[hue]).round(),
          (blue[hue] / weight[hue]).round(),
        ),
      ),
  ];
  if (colours.length == 1) {
    final only = HSLColor.fromColor(colours.first);
    return [
      colours.first,
      only.withHue((only.hue + 35) % 360).toColor(),
      only.withHue((only.hue + 70) % 360).toColor(),
    ];
  }
  return colours;
}

/// [colour] with its saturation and lightness pulled into the range that stays
/// bright and clear on both a light and a dark ground.
Color _clear(Color colour) {
  final hsl = HSLColor.fromColor(colour);
  return hsl
      .withSaturation(hsl.saturation < .7 ? .7 : hsl.saturation)
      .withLightness(hsl.lightness.clamp(.5, .62))
      .toColor();
}
