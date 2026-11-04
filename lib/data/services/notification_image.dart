import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// A picture for a notification: fetched from [url], shrunk to [width] pixels
/// across (a phone's notification shade never needs more, and a big original
/// can make the system refuse the notification) and re-encoded as PNG. Null
/// when there is no [url], it can't be reached in a few seconds, or what comes
/// back isn't a picture — the notification is then shown without it.
///
/// Runs in the background isolate that announces releases, where nothing of
/// the app's image cache is available.
Future<Uint8List?> fetchNotificationImage(
  String? url, {
  int width = 512,
}) async {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return null;

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 8));
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != HttpStatus.ok) return null;
    final bytes = await consolidateHttpClientResponseBytes(
      response,
    ).timeout(const Duration(seconds: 10));

    final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
    final image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    return png?.buffer.asUint8List();
  } catch (error) {
    debugPrint('Notification picture unavailable: $error');
    return null;
  } finally {
    client.close(force: true);
  }
}
