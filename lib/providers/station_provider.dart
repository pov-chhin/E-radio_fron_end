import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/station.dart';
import 'cached_list_notifier.dart';

class StationsNotifier extends CachedListNotifier<Station> {
  @override
  String get path => '/stations';

  @override
  Station fromJson(Map<String, dynamic> json) => Station.fromJson(json);

  @override
  String? imageUrl(Station item) => item.coverUrl;
}

final stationsProvider = AsyncNotifierProvider<StationsNotifier, List<Station>>(
  StationsNotifier.new,
);
