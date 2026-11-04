import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supports/load_ui_image.dart';

/// The colour of a card picture's own background, from its raw RGBA [pixels]:
/// the median of the strips that only ever hold background — the left edge
/// (the title sits further in) and the top and bottom rows of the left half
/// (the illustration is on the right). The median, per channel, so a stray
/// letter or foot in a strip doesn't tint it. Null when the picture is too
/// small, or too transparent, to say.
Color? backgroundColorOf(Uint8List pixels, int width, int height) {
  if (width < 8 || height < 8 || pixels.length < width * height * 4) {
    return null;
  }

  final reds = <int>[];
  final greens = <int>[];
  final blues = <int>[];

  void sample(int x, int y) {
    final i = (y * width + x) * 4;
    if (pixels[i + 3] < 200) return;
    reds.add(pixels[i]);
    greens.add(pixels[i + 1]);
    blues.add(pixels[i + 2]);
  }

  final edge = (width * .06).ceil().clamp(2, width);
  const rows = 3;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < edge; x++) {
      sample(x, y);
    }
  }
  for (var x = edge; x < width ~/ 2; x++) {
    for (var y = 0; y < rows; y++) {
      sample(x, y);
      sample(x, height - 1 - y);
    }
  }

  if (reds.length < 20) return null;

  int median(List<int> values) {
    values.sort();
    return values[values.length ~/ 2];
  }

  return Color.fromARGB(255, median(reds), median(greens), median(blues));
}

/// The background colour of the card picture at a URL (see
/// [backgroundColorOf]), or null if it can't be loaded or read — the page then
/// keeps the mood's own colour. The picture is the one the carousel already
/// loaded, so it comes from the image cache.
final ambientCardColorProvider = FutureProvider.autoDispose
    .family<Color?, String>((ref, url) async {
      try {
        final image = await loadUiImage(
          CachedNetworkImageProvider(url),
        ).timeout(const Duration(seconds: 15));
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (data == null) return null;
          return backgroundColorOf(
            data.buffer.asUint8List(),
            image.width,
            image.height,
          );
        } finally {
          image.dispose();
        }
      } catch (_) {
        return null;
      }
    });
