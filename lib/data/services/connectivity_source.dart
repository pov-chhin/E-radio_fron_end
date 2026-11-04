import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';

/// How the app finds out whether it is online. Behind an interface so a test can
/// say what it likes without touching the phone's network.
abstract class ConnectivitySource {
  /// Fires when the phone's connections change — Wi-Fi or mobile data switched
  /// on or off. It says nothing about whether the internet is really behind
  /// them; that is what [isOnline] is for.
  Stream<void> get changes;

  Future<bool> isOnline();
}

/// The real thing: the phone must have a connection, and something on the
/// internet must answer on it. The second part is what catches Wi-Fi that goes
/// nowhere. The app's own server counts as an answer, but is not required — it
/// being down is a different problem from the phone being offline.
class PlatformConnectivitySource implements ConnectivitySource {
  PlatformConnectivitySource({
    Uri? server,
    List<(String, int)> publicHosts = defaultPublicHosts,
  }) : _server = server ?? Uri.parse(AppConfig.apiBaseUrl),
       _publicHosts = publicHosts;

  static const _probeTimeout = Duration(seconds: 3);

  /// A failed look is looked at once more after this, before the phone is
  /// called offline: a connection that is only changing hands (Wi-Fi to mobile
  /// data) must not put the "No Internet Connection" page over the whole app.
  static const _confirmAfter = Duration(milliseconds: 600);

  /// Well-known public addresses to open a connection to (by number, so no name
  /// lookup is needed): Cloudflare's and Google's resolvers.
  static const defaultPublicHosts = [('1.1.1.1', 443), ('8.8.8.8', 443)];

  /// `flutter test` has no phone behind it.
  static final _inTest =
      !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

  final Uri _server;
  final List<(String, int)> _publicHosts;
  final _connectivity = Connectivity();

  @override
  Stream<void> get changes {
    if (_inTest) return const Stream<void>.empty();
    return _connectivity.onConnectivityChanged
        .handleError((Object _) {})
        .map((_) {});
  }

  @override
  Future<bool> isOnline() async {
    if (_inTest) return true;
    try {
      final connections = await _connectivity.checkConnectivity();
      if (connections.every((c) => c == ConnectivityResult.none)) return false;
    } on MissingPluginException {
      // The running app was built without the plugin (a hot restart after it was
      // added does not add it — only a full rebuild does). Carry on without the
      // list of connections: the probes below tell just as well.
      debugPrint(
        'connectivity_plus is not part of this build — stop the app and run it '
        'again to get connection-change events.',
      );
    } catch (error) {
      debugPrint('Checking the phone\'s connections failed: $error');
    }
    if (await somethingAnswers()) return true;
    await Future<void>.delayed(_confirmAfter);
    return somethingAnswers();
  }

  /// True as soon as any one of the probes gets through; false once all have
  /// failed.
  @visibleForTesting
  Future<bool> somethingAnswers() {
    if (kIsWeb) return Future.value(true);
    final serverPort = _server.hasPort
        ? _server.port
        : (_server.scheme == 'https' ? 443 : 80);
    final probes = [
      _canConnect(_server.host, serverPort),
      for (final (host, port) in _publicHosts) _canConnect(host, port),
    ];

    final answer = Completer<bool>();
    var waiting = probes.length;
    for (final probe in probes) {
      probe.then((reached) {
        if (answer.isCompleted) return;
        if (reached) {
          answer.complete(true);
        } else if (--waiting == 0) {
          answer.complete(false);
        }
      });
    }
    return answer.future;
  }

  /// Opens a connection and drops it again — no request, so nothing is sent.
  Future<bool> _canConnect(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port, timeout: _probeTimeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
