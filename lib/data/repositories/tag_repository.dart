import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../models/tag.dart';

/// The full tag tree in one call (only ~42 rows) so the UI can drill down
/// client-side without a round trip per level.
final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get('/tags');
  final list = (res['data'] as List).cast<Map<String, dynamic>>();
  return list.map(Tag.fromJson).toList();
});
