import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../providers/auth_controller.dart';
import '../../providers/connection_provider.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    this.baseUrl = AppConfig.apiBaseUrl,
    this.defaultToken,
    this.onNetworkError,
  });

  final String baseUrl;

  /// Called when a request fails before the server has answered at all — no
  /// connection, a timeout — so the app can check whether it has gone offline.
  /// The failure is still thrown to the caller as it always was.
  final void Function()? onNetworkError;

  /// The signed-in user's token, sent on calls that don't pass their own. Most
  /// of the app (browsing, playing) hits public endpoints, and sending it there
  /// lets the server see the user is still active so the CMS lists them online.
  final String? Function()? defaultToken;
  final _http = http.Client();

  Map<String, String> _headers(String? token) {
    final bearer = token ?? defaultToken?.call();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (bearer != null) 'Authorization': 'Bearer $bearer',
    };
  }

  /// Sends a request, telling [onNetworkError] if it never got an answer.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } catch (error) {
      if (error is SocketException ||
          error is http.ClientException ||
          error is TimeoutException ||
          error is TlsException) {
        onNetworkError?.call();
      }
      rethrow;
    }
  }

  Future<dynamic> get(String path, {String? token}) async {
    final res = await _send(
      () => _http.get(Uri.parse('$baseUrl$path'), headers: _headers(token)),
    );
    return _decode(res);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final res = await _send(
      () => _http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final res = await _send(
      () => _http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  /// Multipart upload of a single file under [field].
  Future<dynamic> postFile(
    String path, {
    required String field,
    required String filePath,
    String? token,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      })
      ..files.add(await http.MultipartFile.fromPath(field, filePath));
    final res = await _send(
      () async => http.Response.fromStream(await _http.send(request)),
    );
    return _decode(res);
  }

  Future<dynamic> delete(String path, {String? token}) async {
    final res = await _send(
      () => _http.delete(Uri.parse('$baseUrl$path'), headers: _headers(token)),
    );
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) return body;

    final message =
        (body is Map ? body['message'] as String? : null) ?? 'Request failed';
    Map<String, List<String>>? fieldErrors;
    if (body is Map && body['errors'] is Map) {
      fieldErrors = (body['errors'] as Map).map(
        (key, value) => MapEntry(key as String, (value as List).cast<String>()),
      );
    }
    throw ApiException(
      message,
      statusCode: res.statusCode,
      fieldErrors: fieldErrors,
    );
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    defaultToken: () => ref.read(authControllerProvider.notifier).token,
    onNetworkError: () => ref.read(connectionStatusProvider.notifier).recheck(),
  ),
);
