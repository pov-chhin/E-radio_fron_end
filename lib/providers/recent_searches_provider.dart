import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';

const _kRecentSearchesKey = 'recent_searches';
const _kMaxRecentSearches = 10;

/// What the person last searched for, newest first, kept on the device.
class RecentSearchesController extends Notifier<List<String>> {
  @override
  List<String> build() =>
      ref.read(sharedPreferencesProvider).getStringList(_kRecentSearchesKey) ??
      const [];

  /// Puts [term] first; searching the same words again moves them up rather
  /// than listing them twice.
  void add(String term) {
    final text = term.trim();
    if (text.isEmpty) return;
    _save(
      [
        text,
        ...state.where((t) => t.toLowerCase() != text.toLowerCase()),
      ].take(_kMaxRecentSearches).toList(),
    );
  }

  void remove(String term) => _save([...state.where((t) => t != term)]);

  void clear() => _save(const []);

  void _save(List<String> terms) {
    state = terms;
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_kRecentSearchesKey, terms);
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<String>>(
      RecentSearchesController.new,
    );
