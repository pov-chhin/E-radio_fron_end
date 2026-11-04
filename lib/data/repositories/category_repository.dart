import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../models/category.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final client = ref.read(apiClientProvider);
  final res = await client.get('/categories');
  final list = (res['data'] as List).cast<Map<String, dynamic>>();
  return list.map(Category.fromJson).toList();
});
