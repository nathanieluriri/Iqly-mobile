import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_store.dart';

class ApiResponse {
  const ApiResponse(this.status, this.body, {this.headers = const {}});

  final int status;
  final Map<String, dynamic> body;

  /// Lower-case names, as the http package hands them over.
  final Map<String, String> headers;

  bool get ok => status >= 200 && status < 300;

  /// Better Auth's `code`, or the API's `error.code`.
  String? get code {
    final error = body['error'];
    if (error is Map && error['code'] is String) return error['code'] as String;
    final code = body['code'];
    return code is String ? code : null;
  }

  /// Better Auth's `message`, or the API's `error.message`.
  String? get message {
    final error = body['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    final message = body['message'];
    return message is String ? message : null;
  }

  /// The API's `{ success, data }` payload.
  Map<String, dynamic> get data {
    final data = body['data'];
    return data is Map ? data.cast<String, dynamic>() : const {};
  }

  /// The payload when it is a list rather than an object.
  List<Object?> get list {
    final data = body['data'];
    return data is List ? data : const [];
  }

  /// How long a 429 asks to wait, in whole seconds.
  Duration? get retryAfter {
    final seconds = int.tryParse(headers['retry-after']?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }
}

/// An answer kept for a conditional read: the ETag it came with and its
/// body.
typedef TaggedAnswer = ({String etag, Map<String, dynamic> body});

/// Where conditional reads keep each answer with its ETag (contract 13.5),
/// for one person: a tag never answers for anyone else.
abstract class EtagCache {
  Future<TaggedAnswer?> read(String path);
  Future<void> write(String path, TaggedAnswer answer);
}

/// A file the API served, as bytes.
class ApiBytes {
  const ApiBytes(this.status, this.bytes, {this.contentType});

  final int status;
  final Uint8List bytes;
  final String? contentType;

  bool get ok => status >= 200 && status < 300;
}

/// No answer from the API: no connection, a timeout, or the connection
/// failing on the way.
class ApiUnreachable implements Exception {
  const ApiUnreachable({this.nothingSent = false});

  /// The lookup, the connection or its TLS handshake failed before the
  /// request went out, so the API cannot have it.
  final bool nothingSent;

  @override
  String toString() =>
      nothingSent ? 'ApiUnreachable(nothing sent)' : 'ApiUnreachable';
}

/// Whether [error] leaves a read without an answer to trust: no answer at
/// all, or a timeout, a throttle or a fault on the API's side.
bool unanswered(Object error) =>
    error is ApiUnreachable ||
    error is ApiRefused &&
        (error.status == 408 || error.status == 429 || error.status >= 500);

/// An answer the API refused, with its status, code and message.
class ApiRefused implements Exception {
  const ApiRefused(this.status, [this.code, this.message]);

  ApiRefused.of(ApiResponse res) : this(res.status, res.code, res.message);

  final int status;
  final String? code;
  final String? message;

  @override
  String toString() => 'ApiRefused($status${code == null ? '' : ' $code'})';
}

/// A file part of a multipart request.
class ApiFile {
  const ApiFile({
    required this.field,
    required this.filename,
    required this.bytes,
    required this.contentType,
  });

  final String field;
  final String filename;
  final List<int> bytes;

  /// A media type, `image/jpeg` or `application/pdf`.
  final String contentType;
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
    this.appVersion,
    String? platform,
  }) : platform = platform ?? platformName,
       _client = client ?? http.Client();

  final TokenStore tokens;
  final String baseUrl;
  final Duration timeout;

  /// This build as `version+build` (0.3.1+4), sent as `x-app-version`.
  final String? appVersion;

  /// Sent as `x-platform`.
  final String platform;
  final http.Client _client;
  final _unauthorized = StreamController<void>.broadcast();
  final _reachable = StreamController<void>.broadcast();
  var _unreachable = false;

  /// `android`, `ios`, or Flutter's name for any other OS.
  static String get platformName => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    final other => other.name,
  };

  /// Fires when the API answers 401 to the session token this phone still
  /// holds: the session has ended on the server. Better Auth's own routes
  /// answer 401 for a wrong password too, so they never fire it.
  Stream<void> get unauthorized => _unauthorized.stream;

  /// Fires when the API answers again after a request found no network,
  /// which is the phone's surest sign that it is back online.
  Stream<void> get reachable => _reachable.stream;

  /// With [etags] the read is conditional: the ETag kept for [path] goes as
  /// If-None-Match, and a 304 answers the body kept with it as a 200. A
  /// cache that fails to read or write leaves the read as a plain one.
  Future<ApiResponse> get(String path, {EtagCache? etags}) async {
    if (etags == null) return send('GET', path);
    TaggedAnswer? kept;
    try {
      kept = await etags.read(path);
    } on Object catch (error) {
      debugPrint('ETag for $path not read: $error');
    }
    final res = await send(
      'GET',
      path,
      headers: {'if-none-match': ?kept?.etag},
    );
    if (res.status == 304 && kept != null) {
      return ApiResponse(200, kept.body, headers: res.headers);
    }
    final tag = res.headers['etag'];
    if (res.status == 200 && tag != null && tag.isNotEmpty) {
      try {
        await etags.write(path, (etag: tag, body: res.body));
      } on Object catch (error) {
        debugPrint('ETag for $path not kept: $error');
      }
    }
    return res;
  }

  Future<ApiResponse> post(String path, [Map<String, Object?>? body]) =>
      send('POST', path, body: body ?? const {});

  Future<ApiResponse> put(String path, [Map<String, Object?>? body]) =>
      send('PUT', path, body: body ?? const {});

  Future<ApiResponse> patch(String path, [Map<String, Object?>? body]) =>
      send('PATCH', path, body: body ?? const {});

  Future<ApiResponse> delete(String path, [Map<String, Object?>? body]) =>
      send('DELETE', path, body: body);

  /// [body] goes as JSON when given. [idempotencyKey] lets the API answer a
  /// repeat of the same write with the row the first one made.
  Future<ApiResponse> send(
    String method,
    String path, {
    Object? body,
    String? idempotencyKey,
    Map<String, String> headers = const {},
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(headers);
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _dispatch(request, path, idempotencyKey: idempotencyKey);
  }

  /// Posts [fields] and [files] as multipart/form-data. [onProgress] goes
  /// from 0 to 1 as the connection takes the body. [timeout] counts from
  /// the last bytes sent, so a slow upload that keeps moving is never cut
  /// off.
  Future<ApiResponse> multipart(
    String path, {
    required Map<String, String> fields,
    List<ApiFile> files = const [],
    void Function(double progress)? onProgress,
    String? idempotencyKey,
    String method = 'POST',
  }) async {
    final stalled = Completer<void>();
    Timer? idle;
    void moving() {
      idle?.cancel();
      idle = Timer(timeout, () {
        if (!stalled.isCompleted) stalled.complete();
      });
    }

    final request =
        _Upload(
            method,
            Uri.parse('$baseUrl$path'),
            abortTrigger: stalled.future,
            onSent: (sent, total) {
              moving();
              onProgress?.call(total == 0 ? 1.0 : sent / total);
            },
          )
          ..fields.addAll(fields)
          ..files.addAll([
            for (final file in files)
              http.MultipartFile(
                file.field,
                _pieces(file.bytes),
                file.bytes.length,
                filename: file.filename,
                contentType: http.MediaType.parse(file.contentType),
              ),
          ]);
    onProgress?.call(0);
    moving();
    try {
      return await _dispatch(
        request,
        path,
        idempotencyKey: idempotencyKey,
        stalled: stalled.future,
      );
    } finally {
      idle?.cancel();
    }
  }

  /// [url] on this client's API: only its path and query are kept, so a
  /// link that carries the session token never leaves for another host.
  Uri authorized(String url) {
    final given = Uri.parse(url);
    final path = given.hasQuery ? '${given.path}?${given.query}' : given.path;
    return Uri.parse('$baseUrl$path');
  }

  /// The headers a player or an image sends to read a signed-in file.
  Future<Map<String, String>> fileHeaders() async {
    final token = await tokens.read();
    return {
      'x-iqly-client': 'mobile',
      'x-platform': platform,
      if (token != null) 'authorization': 'Bearer $token',
    };
  }

  /// The file the API serves at [url], read with the session token. Only
  /// the path and query of [url] are kept, so the token never goes to any
  /// host but the API's.
  Future<ApiBytes> download(String url) async {
    final request = await _fileRequest(url);
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiUnreachable();
    } on http.ClientException catch (error) {
      throw ApiUnreachable(nothingSent: _beforeSending(error));
    } on IOException catch (error) {
      throw ApiUnreachable(nothingSent: _beforeSending(error));
    }
    return ApiBytes(
      response.statusCode,
      response.bodyBytes,
      contentType: response.headers['content-type'],
    );
  }

  /// Writes the file the API serves at [url] to [target] as it arrives,
  /// [onProgress] going from 0 to 1 when the API says the size. [timeout]
  /// counts from the last bytes received. Throws [ApiUnreachable] without a
  /// whole answer, [ApiRefused] when the API refuses.
  Future<void> downloadTo(
    String url,
    File target, {
    void Function(double progress)? onProgress,
  }) async {
    final request = await _fileRequest(url);
    final IOSink sink;
    try {
      final response = await _client.send(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw ApiRefused(response.statusCode);
      }
      final total = response.contentLength;
      var received = 0;
      onProgress?.call(0);
      sink = target.openWrite();
      try {
        await for (final chunk in response.stream.timeout(timeout)) {
          sink.add(chunk);
          received += chunk.length;
          if (total != null && total > 0) {
            onProgress?.call((received / total).clamp(0, 1));
          }
        }
      } finally {
        await sink.close();
      }
    } on TimeoutException {
      throw const ApiUnreachable();
    } on http.ClientException catch (error) {
      throw ApiUnreachable(nothingSent: _beforeSending(error));
    } on IOException catch (error) {
      throw ApiUnreachable(nothingSent: _beforeSending(error));
    }
    onProgress?.call(1);
  }

  Future<http.Request> _fileRequest(String url) async {
    final request = http.Request('GET', authorized(url));
    final token = await tokens.read();
    request.headers.addAll({
      'x-iqly-client': 'mobile',
      'x-app': 'web',
      'x-app-version': ?appVersion,
      'x-platform': platform,
      if (token != null) 'authorization': 'Bearer $token',
    });
    return request;
  }

  Future<ApiResponse> _dispatch(
    http.BaseRequest request,
    String path, {
    String? idempotencyKey,
    Future<void>? stalled,
  }) async {
    request.headers.addAll({
      'accept': 'application/json',
      'x-iqly-client': 'mobile',
      'x-app': 'web',
      'x-app-version': ?appVersion,
      'x-platform': platform,
      'idempotency-key': ?idempotencyKey,
    });
    final token = await tokens.read();
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    final http.Response response;
    try {
      final sending = _client.send(request);
      final streamed = stalled == null
          ? await sending.timeout(timeout)
          : await Future.any([
              sending,
              stalled.then<http.StreamedResponse>(
                (_) => throw TimeoutException('Upload stalled', timeout),
              ),
            ]);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      _unreachable = true;
      throw const ApiUnreachable();
    } on http.ClientException catch (error) {
      _unreachable = true;
      throw ApiUnreachable(nothingSent: _beforeSending(error));
    } on IOException catch (error) {
      _unreachable = true;
      throw ApiUnreachable(nothingSent: _beforeSending(error));
    }
    if (_unreachable) {
      _unreachable = false;
      _reachable.add(null);
    }
    // With requireSignature the API only accepts the signed token from this
    // header, never the raw one in a sign-in body.
    final issued = response.headers['set-auth-token'];
    if (issued != null && issued.isNotEmpty) await tokens.write(issued);
    if (response.statusCode == 401 &&
        token != null &&
        !path.startsWith('/auth/') &&
        await tokens.read() == token) {
      _unauthorized.add(null);
    }
    return ApiResponse(
      response.statusCode,
      _decode(response.body),
      headers: response.headers,
    );
  }

  /// dart:io names a failed lookup and a failed connect this way, and a TLS
  /// handshake runs before any of the request is written; every other
  /// failure may come after the API has the request.
  static bool _beforeSending(Object error) => switch (error) {
    HandshakeException() => true,
    SocketException(:final message) =>
      message.startsWith('Failed host lookup') ||
          message.startsWith('Connection failed'),
    _ => false,
  };

  /// A file read out in small pieces, so progress follows the connection
  /// rather than leaping to the end with one write.
  static Stream<List<int>> _pieces(List<int> bytes) async* {
    const piece = 64 * 1024;
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    for (var start = 0; start < data.length; start += piece) {
      yield Uint8List.sublistView(data, start, min(start + piece, data.length));
    }
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

/// A multipart body that reports how much of it the connection has read.
class _Upload extends http.MultipartRequest with http.Abortable {
  _Upload(super.method, super.url, {required this.onSent, this.abortTrigger});

  final void Function(int sent, int total) onSent;

  @override
  final Future<void>? abortTrigger;

  @override
  http.ByteStream finalize() {
    final body = super.finalize();
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      body.map((chunk) {
        sent += chunk.length;
        onSent(sent, total);
        return chunk;
      }),
    );
  }
}

/// The client every live service shares, null in the preview build.
final apiClientProvider = Provider<ApiClient?>((ref) => null);
