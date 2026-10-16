import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_store.dart';

class ApiResponse {
  const ApiResponse(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;

  bool get ok => status >= 200 && status < 300;

  /// Better Auth's `code`, or the API's `error.code`.
  String? get code {
    final error = body['error'];
    if (error is Map && error['code'] is String) return error['code'] as String;
    return body['code'] as String?;
  }

  /// The API's `{ success, data }` payload.
  Map<String, dynamic> get data =>
      (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
}

/// No answer from the API: no connection, or it timed out.
class ApiUnreachable implements Exception {
  const ApiUnreachable();
}

/// Talks JSON to the iQLY API with the session token the API last handed
/// out. Every request says it comes from the mobile app, so auth emails
/// codes instead of links.
class ApiClient {
  ApiClient({
    required this.tokens,
    http.Client? client,
    this.baseUrl = ApiConfig.baseUrl,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final TokenStore tokens;
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  Future<ApiResponse> get(String path) => _send('GET', path, null);

  Future<ApiResponse> post(String path, [Map<String, Object?>? body]) =>
      _send('POST', path, body ?? const {});

  Future<ApiResponse> _send(
    String method,
    String path,
    Map<String, Object?>? body,
  ) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'accept': 'application/json',
        'x-iqly-client': 'mobile',
        'x-app': 'web',
      });
    final token = await tokens.read();
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiUnreachable();
    } on http.ClientException {
      throw const ApiUnreachable();
    }
    // With requireSignature the API only accepts the signed token from this
    // header, never the raw one in a sign-in body.
    final issued = response.headers['set-auth-token'];
    if (issued != null && issued.isNotEmpty) await tokens.write(issued);
    return ApiResponse(response.statusCode, _decode(response.body));
  }

  static Map<String, dynamic> _decode(String text) {
    if (text.isEmpty) return const {};
    try {
      final value = jsonDecode(text);
      return value is Map<String, dynamic> ? value : const {};
    } on FormatException {
      return const {};
    }
  }
}
