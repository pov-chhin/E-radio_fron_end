import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts or stops the phone's background check for new releases.
abstract class ReleaseAlertScheduler {
  /// [enabled] is the Notifications switch: on means check from now on, off
  /// means stop.
  Future<void> sync(bool enabled);
}

/// Does nothing — where there is no background check (tests, and every platform
/// but Android).
class NoReleaseAlerts implements ReleaseAlertScheduler {
  const NoReleaseAlerts();

  @override
  Future<void> sync(bool enabled) async {}
}

/// Overridden in main() with the real scheduler once the app is up.
final releaseAlertSchedulerProvider = Provider<ReleaseAlertScheduler>(
  (ref) => const NoReleaseAlerts(),
);
