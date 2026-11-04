import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/views/widgets/music/ambient_palette.dart';

/// A [width]×[height] RGBA picture filled with [background]; [paint] then draws
/// rectangles on it.
Uint8List _picture(
  int width,
  int height,
  Color background,
  void Function(void Function(int x0, int y0, int x1, int y1, Color color) fill)
  paint,
) {
  final pixels = Uint8List(width * height * 4);
  void fill(int x0, int y0, int x1, int y1, Color color) {
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = (y * width + x) * 4;
        pixels[i] = (color.r * 255).round();
        pixels[i + 1] = (color.g * 255).round();
        pixels[i + 2] = (color.b * 255).round();
        pixels[i + 3] = (color.a * 255).round();
      }
    }
  }

  fill(0, 0, width, height, background);
  paint(fill);
  return pixels;
}

void main() {
  const background = Color(0xFF1D2A44);

  test('reads the background, not the title or the illustration', () {
    final pixels = _picture(200, 100, background, (fill) {
      // The title, in white, on the left but away from the edge…
      fill(30, 40, 90, 60, const Color(0xFFFFFFFF));
      // …and the illustration on the right, top to bottom.
      fill(120, 0, 180, 100, const Color(0xFFFF0000));
    });

    expect(backgroundColorOf(pixels, 200, 100), background);
  });

  test('a letter touching the edge strip does not tint it', () {
    final pixels = _picture(200, 100, background, (fill) {
      fill(0, 40, 4, 44, const Color(0xFFFFFFFF));
    });

    expect(backgroundColorOf(pixels, 200, 100), background);
  });

  test('ignores transparent pixels', () {
    final pixels = _picture(200, 100, background, (fill) {
      // A rounded corner left see-through.
      fill(0, 0, 8, 8, const Color(0x00000000));
    });

    expect(backgroundColorOf(pixels, 200, 100), background);
  });

  test('says nothing for a picture too small or too transparent to read', () {
    expect(backgroundColorOf(Uint8List(4 * 4 * 4), 4, 4), isNull);
    final clear = _picture(200, 100, const Color(0x00000000), (fill) {});
    expect(backgroundColorOf(clear, 200, 100), isNull);
    // A buffer shorter than the size it claims.
    expect(backgroundColorOf(Uint8List(100), 200, 100), isNull);
  });
}
