import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/api_client.dart';
import '../data/services/image_warmer.dart';
import '../data/services/list_cache.dart';
import 'list_cache_provider.dart';

/// A list from the API that shows up instantly: the top of it is kept on the
/// device, so this starts with that (or with what it already holds in memory)
/// and fetches the real list behind it, swapping it in when it arrives.
/// Offline, or if the server fails, the screen simply keeps what it has.
///
/// Only the first [kTopCacheLimit] items are stored — and only their pictures
/// are downloaded ahead of time — since that is what the top of the screen
/// needs.
abstract class CachedListNotifier<T> extends AsyncNotifier<List<T>> {
  /// The API path that returns the list, under a `data` key — also what the
  /// stored top of the list is filed under.
  String get path;

  T fromJson(Map<String, dynamic> json);

  /// The picture [item] draws on the top of the screen.
  String? imageUrl(T item);

  @override
  FutureOr<List<T>> build() {
    final shown = state.value ?? _fromDisk();
    if (shown == null) return _fetch();
    unawaited(_revalidate());
    return shown;
  }

  /// Pull-to-refresh and Retry: a real fetch the caller can wait on, rather
  /// than the instant answer a rebuild gives.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  List<T>? _fromDisk() {
    final stored = ref.read(listCacheProvider).read(path);
    if (stored == null) return null;
    try {
      return stored.map(fromJson).toList();
    } catch (_) {
      // Written by an older version of the app: treat it as not there.
      return null;
    }
  }

  Future<List<T>> _fetch() async {
    final client = ref.read(apiClientProvider);
    final cache = ref.read(listCacheProvider);
    final warmer = ref.read(imageWarmerProvider);

    final res = await client.get(path);
    final raw = (res['data'] as List).cast<Map<String, dynamic>>();
    final items = raw.map(fromJson).toList();

    unawaited(cache.write(path, raw));
    unawaited(warmer.warm(items.take(kTopCacheLimit).map(imageUrl)));
    return items;
  }

  Future<void> _revalidate() async {
    try {
      final fresh = await _fetch();
      if (ref.mounted) state = AsyncData(fresh);
    } catch (_) {}
  }
}
