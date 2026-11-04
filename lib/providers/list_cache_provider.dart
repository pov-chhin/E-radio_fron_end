import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/list_cache.dart';
import 'shared_preferences_provider.dart';

final listCacheProvider = Provider<ListCache>(
  (ref) => ListCache(ref.watch(sharedPreferencesProvider)),
);
