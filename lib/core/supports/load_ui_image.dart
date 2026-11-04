import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The decoded picture behind an [ImageProvider], for reading its pixels. The
/// caller owns it and disposes it.
Future<ui.Image> loadUiImage(ImageProvider provider) {
  final completer = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      // A clone: the stream may dispose its own copy once we stop listening.
      if (!completer.isCompleted) completer.complete(info.image.clone());
      stream.removeListener(listener);
    },
    onError: (error, stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return completer.future;
}
