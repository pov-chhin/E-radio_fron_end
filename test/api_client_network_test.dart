import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:e_radio/data/services/api_client.dart';
import 'package:e_radio/data/services/api_exception.dart';

/// Nothing listens on port 1, so a request there never gets an answer.
const _nowhere = 'http://127.0.0.1:1';

void main() {
  // Flutter's test harness answers every HTTP request itself, so nothing would
  // ever fail to connect. These tests need the real thing — a port on this
  // machine, nothing leaves it.
  setUpAll(() => HttpOverrides.global = null);

  group('ApiClient tells the app when a request cannot get through', () {
    final calls = <String, Future<dynamic> Function(ApiClient client)>{
      'get': (client) => client.get('/x'),
      'post': (client) => client.post('/x', {'a': 1}),
      'put': (client) => client.put('/x', {'a': 1}),
      'delete': (client) => client.delete('/x'),
    };

    for (final entry in calls.entries) {
      test('${entry.key}: reports it, and still throws', () async {
        var told = 0;
        final client = ApiClient(
          baseUrl: _nowhere,
          onNetworkError: () => told++,
        );

        await expectLater(entry.value(client), throwsA(anything));

        expect(told, 1);
      });
    }

    test(
      'an answer from the server, even an error, is not a network failure',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) {
          request.response
            ..statusCode = 404
            ..headers.contentType = ContentType.json
            ..write('{"message":"Not found"}')
            ..close();
        });
        var told = 0;
        final client = ApiClient(
          baseUrl: 'http://127.0.0.1:${server.port}',
          onNetworkError: () => told++,
        );

        await expectLater(client.get('/x'), throwsA(isA<ApiException>()));

        expect(told, 0);
      },
    );

    test('works without anyone listening', () async {
      final client = ApiClient(baseUrl: _nowhere);

      await expectLater(client.get('/x'), throwsA(anything));
    });
  });
}
