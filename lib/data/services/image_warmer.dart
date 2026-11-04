import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Downloads pictures into the on-disk image cache ahead of time, so when a
/// screen asks for them (through `CachedNetworkImage`, which reads the same
/// cache) they are already on the device. Strictly best-effort and never
/// awaited by the UI: a failed download is just a picture that loads the
/// usual way later.
class ImageWarmer {
  const ImageWarmer();

  /// A few at a time per call, so warming never crowds out what the screen
  /// itself is loading.
  static const _parallel = 3;

  Future<void> warm(Iterable<String?> urls) async {
    final pending = {
      for (final url in urls)
        if (url != null && url.isNotEmpty) url,
    }.iterator;

    // Each worker takes the next picture as soon as it finishes its last, so
    // one slow download holds up only its own slot.
    Future<void> worker() async {
      while (pending.moveNext()) {
        await _download(pending.current);
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
  }

  /// A no-op when the picture is already cached and fresh.
  Future<void> _download(String url) async {
    try {
      await CachedNetworkImageProvider.defaultCacheManager.getSingleFile(url);
    } catch (_) {}
  }
}

final imageWarmerProvider = Provider<ImageWarmer>((ref) => const ImageWarmer());
