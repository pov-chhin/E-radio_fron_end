import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../models/artist.dart';

/// Up to ten music artists, most-played first. [tagIds] (comma-joined, empty
/// for everyone) keeps only those with a song under one of those tags or a tag
/// nested in them — how "Local" and "International" narrow the list.
final popularArtistsProvider = FutureProvider.family<List<Artist>, String>((
  ref,
  tagIds,
) async {
  final client = ref.read(apiClientProvider);
  final tags = tagIds.isEmpty ? '' : '&tag_ids=$tagIds';
  final res = await client.get('/artists?category=song$tags');
  final list = (res['data'] as List).cast<Map<String, dynamic>>();
  return list.map(Artist.fromJson).toList();
});
