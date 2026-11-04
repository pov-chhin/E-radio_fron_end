import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The payload of each notification tapped while the app is running (open, or
/// in the background). Nothing in tests; overridden in main() with the phone's.
final notificationTapsProvider = Provider<Stream<String>>(
  (ref) => const Stream.empty(),
);

/// The payload of the notification whose tap started the app from closed, if
/// that is how it was started.
final launchNotificationPayloadProvider = Provider<String?>((ref) => null);
