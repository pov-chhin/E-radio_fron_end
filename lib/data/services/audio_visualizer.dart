import 'dart:async';

import 'package:flutter/services.dart';

/// How loud each part of the sound is, read from the player's audio so the
/// playing bars can follow the music. Android only — `AudioVisualizer.kt` on the
/// other end of the channels; anywhere else every call says no.
///
/// Android lets an app read the audio levels only with the RECORD_AUDIO
/// permission, so [hasPermission] and [requestPermission] come first. Nothing
/// is recorded: only [bands] loudness numbers come back, a few times a second.
class AudioVisualizer {
  const AudioVisualizer();

  /// How many stretches of the spectrum there are, from bass to treble — one
  /// for each bar.
  static const bands = 10;

  static const _methods = MethodChannel('e_radio/visualizer');
  static const _events = EventChannel('e_radio/visualizer/levels');

  Future<bool> hasPermission() => _ask('hasPermission');

  /// Shows the system's question. True if the answer is yes.
  Future<bool> requestPermission() => _ask('requestPermission');

  /// Starts listening to the Android audio session [sessionId] (the player's;
  /// it changes when the player does). False if the phone won't let it.
  Future<bool> start(int sessionId) =>
      _ask('start', <String, Object>{'sessionId': sessionId});

  Future<void> stop() => _ask('stop');

  /// The loudness of each of the [bands], raw, from the native side — about 0 to
  /// 100, loudest in the bass. Silent until [start] has said yes.
  Stream<List<double>> get levels => _events.receiveBroadcastStream().map(
    (event) => [for (final level in event as List) (level as num).toDouble()],
  );

  Future<bool> _ask(String method, [Object? arguments]) async {
    try {
      return await _methods.invokeMethod<bool>(method, arguments) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
