import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/shared_preferences_provider.dart';
import '../models/artist.dart';
import '../models/category.dart';
import '../models/media_content.dart';
import '../models/program.dart';
import '../models/tag.dart';
import '../services/api_client.dart';

class HomeData {
  const HomeData({
    required this.trending,
    required this.newReleases,
    required this.feeds,
    required this.programs,
    required this.categories,
    required this.tags,
    required this.artists,
  });

  final List<MediaContent> trending;
  final List<MediaContent> newReleases;
  final Map<String, List<MediaContent>> feeds;
  final List<Program> programs;
  final List<Category> categories;
  final List<Tag> tags;
  final List<Artist> artists;

  factory HomeData.fromJson(Map<String, dynamic> json) => HomeData(
    trending: _list(json['trending'], MediaContent.fromJson),
    newReleases: _list(json['new_releases'], MediaContent.fromJson),
    feeds: {
      for (final entry in (json['feeds'] as Map<String, dynamic>).entries)
        entry.key: _list(entry.value, MediaContent.fromJson),
    },
    programs: _list(json['programs'], Program.fromJson),
    categories: _list(json['categories'], Category.fromJson),
    tags: _list(json['tags'], Tag.fromJson),
    artists: _list(json['artists'], Artist.fromJson),
  );

  static List<T> _list<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parse,
  ) => (value as List)
      .map((item) => parse(item as Map<String, dynamic>))
      .toList();
}

class HomeNotifier extends AsyncNotifier<HomeData> {
  static const _cacheKey = 'home.v1';

  @override
  FutureOr<HomeData> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_cacheKey);
    if (raw != null) {
      try {
        final cached = HomeData.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        unawaited(_revalidate());
        return cached;
      } catch (_) {}
    }
    return _fetch();
  }

  Future<void> refresh() async {
    final fresh = await _fetch();
    if (ref.mounted) state = AsyncData(fresh);
  }

  Future<HomeData> _fetch() async {
    final response = await ref.read(apiClientProvider).get('/home');
    final raw = (response['data'] as Map).cast<String, dynamic>();
    unawaited(
      ref.read(sharedPreferencesProvider).setString(_cacheKey, jsonEncode(raw)),
    );
    return HomeData.fromJson(raw);
  }

  Future<void> _revalidate() async {
    try {
      final fresh = await _fetch();
      if (ref.mounted) state = AsyncData(fresh);
    } catch (_) {}
  }
}

final homeProvider = AsyncNotifierProvider<HomeNotifier, HomeData>(
  HomeNotifier.new,
);
