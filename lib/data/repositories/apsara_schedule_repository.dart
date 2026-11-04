import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../models/apsara_station.dart';
import '../models/program_slot.dart';
import '../services/api_exception.dart';

/// How long a fetched schedule is kept once nothing is looking at it.
const _scheduleLifetime = Duration(hours: 1);

/// What time it is where the stations are: Phnom Penh, UTC+7 all year. The
/// schedule is in that time whatever the phone's own zone is. The result's
/// fields are the wall clock there (it is marked UTC only so they are not
/// shifted again); a test swaps in its own.
final apsaraClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc().add(const Duration(hours: 7)),
);

final scheduleHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Every airing of the week of [station]; [DaySchedule] picks out the day. Kept
/// for an hour after the player is closed, so opening it again is instant; a
/// failure is not kept.
final apsaraScheduleProvider = FutureProvider.autoDispose
    .family<List<ProgramSlot>, ApsaraStation>((ref, station) async {
      final client = ref.watch(scheduleHttpClientProvider);
      final url = Uri.parse(AppConfig.apsaraProgramsUrl).replace(
        queryParameters: {
          'per_page': '100',
          // Gives each program's picture as an object with its sizes rather
          // than a bare media id.
          'acf_format': 'standard',
          'parent': '${station.parentId}',
        },
      );
      final res = await client
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw ApiException(
          'Could not load the schedule',
          statusCode: res.statusCode,
        );
      }
      final slots = ProgramSlot.fromProgramsJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>,
      );

      if (ref.mounted) {
        final keep = ref.keepAlive();
        final expiry = Timer(_scheduleLifetime, keep.close);
        ref.onDispose(expiry.cancel);
      }
      return slots;
    });
