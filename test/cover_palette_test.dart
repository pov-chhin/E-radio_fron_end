import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/core/supports/cover_palette.dart';

/// A [width] × [height] picture, as raw RGBA, with [colour] giving each pixel.
Uint8List _picture(int width, int height, Color Function(int x, int y) colour) {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final argb = colour(x, y).toARGB32();
      final at = (y * width + x) * 4;
      bytes[at] = (argb >> 16) & 0xFF;
      bytes[at + 1] = (argb >> 8) & 0xFF;
      bytes[at + 2] = argb & 0xFF;
      bytes[at + 3] = (argb >> 24) & 0xFF;
    }
  }
  return bytes;
}

List<Color>? _colours(Color Function(int x, int y) colour) =>
    coverBarColorsOf(_picture(30, 30, colour), 30, 30);

double _hue(Color colour) => HSLColor.fromColor(colour).hue;

void main() {
  group('coverBarColorsOf', () {
    test('one colour gives it and its two neighbours on the wheel', () {
      final colours = _colours((_, _) => const Color(0xFFE53935))!;

      expect(colours, hasLength(3));
      final hues = colours.map(_hue).toList();
      // Red, then 35° and 70° further round.
      expect(hues[1] - hues[0], closeTo(35, 3));
      expect(hues[2] - hues[0], closeTo(70, 3));
      expect(hues[0], anyOf(lessThan(8), greaterThan(352)));
    });

    test('two colours give the two, in order round the wheel', () {
      final colours = _colours(
        (x, _) => x < 15 ? const Color(0xFF0000FF) : const Color(0xFFFF0000),
      )!;

      expect(colours, hasLength(2));
      expect(_hue(colours[0]), lessThan(10)); // red comes before blue
      expect(_hue(colours[1]), closeTo(240, 10));
    });

    test('three colours give all three', () {
      final colours = _colours((x, _) {
        if (x < 10) return const Color(0xFFFF0000);
        if (x < 20) return const Color(0xFF00FF00);
        return const Color(0xFF0000FF);
      })!;

      expect(colours, hasLength(3));
      expect(_hue(colours[1]), closeTo(120, 10));
      expect(_hue(colours[2]), closeTo(240, 10));
    });

    test('hues side by side count as one colour', () {
      // Orange and yellow are neighbours: they would read as one bar colour.
      final colours = _colours(
        (x, _) => x < 15 ? const Color(0xFFFF8000) : const Color(0xFFFFFF00),
      )!;

      expect(colours, hasLength(3));
      expect(_hue(colours[1]) - _hue(colours[0]), closeTo(35, 3));
    });

    test('every colour is brightened to a clear mid tone', () {
      // A pale pink and a dark navy, both far from the range.
      final colours = _colours(
        (x, _) => x < 15 ? const Color(0xFFFFB3B3) : const Color(0xFF1A2A6C),
      )!;

      for (final colour in colours) {
        final hsl = HSLColor.fromColor(colour);
        expect(hsl.saturation, greaterThanOrEqualTo(.69));
        expect(hsl.lightness, inInclusiveRange(.49, .63));
      }
    });

    test('a grey, black or white picture has no colours to take', () {
      expect(_colours((_, _) => const Color(0xFF808080)), isNull);
      expect(_colours((_, _) => const Color(0xFF000000)), isNull);
      expect(_colours((_, _) => const Color(0xFFFFFFFF)), isNull);
    });

    test('a transparent picture has no colours to take', () {
      expect(_colours((_, _) => const Color(0x00FF0000)), isNull);
    });

    test('a few coloured pixels in a grey picture are not enough', () {
      // 2 of 900 pixels.
      final colours = _colours(
        (x, y) =>
            y == 0 && x < 2 ? const Color(0xFFFF0000) : const Color(0xFF808080),
      );

      expect(colours, isNull);
    });

    test('a picture with fewer pixels than it says is not read', () {
      expect(coverBarColorsOf(Uint8List(16), 30, 30), isNull);
      expect(coverBarColorsOf(Uint8List(0), 0, 0), isNull);
    });
  });
}
