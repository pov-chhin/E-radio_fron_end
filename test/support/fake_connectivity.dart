import 'dart:async';

import 'package:e_radio/data/services/connectivity_source.dart';

/// A connection a test can switch on and off. [checks] counts how often the app
/// asked whether it was online.
class FakeConnectivitySource implements ConnectivitySource {
  FakeConnectivitySource({this.online = true});

  bool online;
  int checks = 0;

  /// Held back, when set, until it completes — a check that takes a while.
  Completer<void>? hold;

  /// Thrown by the next checks, when set — a source that cannot answer.
  Object? error;

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<bool> isOnline() async {
    checks++;
    await hold?.future;
    if (error != null) throw error!;
    return online;
  }

  /// The phone's connections changed (Wi-Fi switched off, say).
  void connectionsChanged() => _changes.add(null);

  Future<void> close() => _changes.close();
}
