import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supports/cover_palette.dart';
import '../core/supports/load_ui_image.dart';
import 'audio_player_controller.dart';

/// The bar colours of the cover picture at a URL (see [coverBarColorsOf]), or
/// null if it can't be loaded or has no colour to take. The picture is the one
/// already on the phone, shown by the player, so this is quick — and it is
/// decoded tiny, as only its broad colours matter.
final coverBarColorsProvider = FutureProvider.autoDispose
    .family<List<Color>?, String>((ref, url) async {
      try {
        final image = await loadUiImage(
          ResizeImage(CachedNetworkImageProvider(url), width: 48, height: 48),
        );
        try {
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (data == null) return null;
          return coverBarColorsOf(
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

/// The colours for the bars of what is playing — its cover's — or null, for the
/// bars' own, while they are still being read or it has no cover, or none to
/// take.
final playingBarColorsProvider = Provider.autoDispose<List<Color>?>((ref) {
  final url = ref.watch(
    audioPlayerControllerProvider.select(
      (playback) => playback.item?.artworkUrl,
    ),
  );
  if (url == null || url.isEmpty) return null;
  return ref.watch(coverBarColorsProvider(url)).value;
});
