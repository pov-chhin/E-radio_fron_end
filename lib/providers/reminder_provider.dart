import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';
import '../data/services/reminder_service.dart';

/// Overridden in main() once the plugin is initialized (timezone data loaded,
/// notification channel created).
final reminderServiceProvider = Provider<ReminderService>((ref) {
  throw UnimplementedError(
    'reminderServiceProvider must be overridden before use',
  );
});

const _kRemindersKey = 'scheduled_reminders';

/// Reminders the user has set for specific NowPlayingItems, keyed by item id.
/// Purely local (SharedPreferences + a device notification) — no backend.
class RemindersController extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_kRemindersKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, DateTime.parse(value as String)),
    );
  }

  DateTime? reminderFor(String itemId) => state[itemId];

  /// Returns false if notification permission was denied — callers should
  /// tell the user to enable it in system settings.
  Future<bool> set(String itemId, String title, DateTime at) async {
    final service = ref.read(reminderServiceProvider);
    if (!await service.requestPermission()) return false;

    await service.schedule(itemId: itemId, title: title, at: at);
    _update({...state, itemId: at});
    return true;
  }

  Future<void> cancel(String itemId) async {
    await ref.read(reminderServiceProvider).cancel(itemId);
    _update({...state}..remove(itemId));
  }

  void _update(Map<String, DateTime> next) {
    state = next;
    final encoded = jsonEncode(
      next.map((key, value) => MapEntry(key, value.toIso8601String())),
    );
    ref.read(sharedPreferencesProvider).setString(_kRemindersKey, encoded);
  }
}

final remindersProvider =
    NotifierProvider<RemindersController, Map<String, DateTime>>(
      RemindersController.new,
    );
