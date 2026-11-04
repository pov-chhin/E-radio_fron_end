import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/data/services/connectivity_source.dart';

/// Opens a listening port on this machine; closed again when the test ends.
Future<int> _listen() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(server.close);
  server.listen((socket) => socket.destroy());
  return server.port;
}

/// A port with nothing on it: bound to learn a free number, then let go.
Future<int> _closedPort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

const _loopback = '127.0.0.1';

void main() {
  group('Telling "offline" from "the server is down"', () {
    test('is online when the app\'s server answers', () async {
      final source = PlatformConnectivitySource(
        server: Uri.parse('http://$_loopback:${await _listen()}'),
        publicHosts: [(_loopback, await _closedPort())],
      );

      expect(await source.somethingAnswers(), isTrue);
    });

    test('is still online when only the server is down', () async {
      final source = PlatformConnectivitySource(
        server: Uri.parse('http://$_loopback:${await _closedPort()}'),
        publicHosts: [(_loopback, await _listen())],
      );

      expect(await source.somethingAnswers(), isTrue);
    });

    test('is offline when nothing at all answers', () async {
      final source = PlatformConnectivitySource(
        server: Uri.parse('http://$_loopback:${await _closedPort()}'),
        publicHosts: [
          (_loopback, await _closedPort()),
          (_loopback, await _closedPort()),
        ],
      );

      expect(await source.somethingAnswers(), isFalse);
    });

    test('knows nothing of a phone under test, and says online', () async {
      final source = PlatformConnectivitySource(
        server: Uri.parse('http://$_loopback:${await _closedPort()}'),
        publicHosts: const [],
      );

      // flutter test has no connections to look at: not a reason to cry offline.
      expect(await source.isOnline(), isTrue);
      expect(await source.changes.isEmpty, isTrue);
    });
  });
}
