import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/api_client.dart';
import 'auth_controller.dart';

/// A user's saved stations/media-content, synced with the backend — distinct
/// from [favoritesProvider], which is local-only. Ids are "type:id" strings
/// (e.g. "media:12"), matching NowPlayingItem.id.
class BookmarksController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    if (ref.watch(authControllerProvider) == null) return {};
    final client = ref.read(apiClientProvider);
    final token = ref.read(authControllerProvider.notifier).token;
    final res = await client.get('/bookmarks', token: token);
    return (res['data'] as List).cast<String>().toSet();
  }

  Future<void> toggle(String type, String id) async {
    if (ref.read(authControllerProvider) == null) return;
    final key = '$type:$id';
    final current = state.value ?? <String>{};
    final next = {...current};
    if (!next.remove(key)) next.add(key);
    state = AsyncData(next);

    try {
      final client = ref.read(apiClientProvider);
      final token = ref.read(authControllerProvider.notifier).token;
      await client.post('/bookmarks/toggle', {
        'type': type,
        'id': int.parse(id),
      }, token: token);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  bool isBookmarked(String type, String id) =>
      (state.value ?? const {}).contains('$type:$id');
}

final bookmarksProvider =
    AsyncNotifierProvider<BookmarksController, Set<String>>(
      BookmarksController.new,
    );
