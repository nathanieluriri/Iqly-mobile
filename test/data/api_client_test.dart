import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/token_store.dart';

/// Keeps every request and answers each with [answer].
class _Api {
  _Api([this.answer]);

  http.Response Function(http.Request request)? answer;
  final requests = <http.Request>[];

  http.Client get client => MockClient((request) async {
    requests.add(request);
    return answer?.call(request) ??
        http.Response(jsonEncode({'success': true, 'data': {}}), 200);
  });

  http.Request get last => requests.last;
}

ApiClient _client(
  http.Client client, {
  String? token,
  TokenStore? tokens,
  String? appVersion = '0.3.1+4',
  String? platform,
  Duration timeout = const Duration(seconds: 20),
}) => ApiClient(
  tokens: tokens ?? MemoryTokenStore(token),
  client: client,
  baseUrl: 'https://api.test',
  appVersion: appVersion,
  platform: platform,
  timeout: timeout,
);

http.Response _json(int status, Object body, {Map<String, String>? headers}) =>
    http.Response(jsonEncode(body), status, headers: headers ?? const {});

void main() {
  group('methods', () {
    test('each sends its method, path and JSON body', () async {
      final api = _Api();
      final client = _client(api.client);
      await client.get('/me');
      await client.post('/me/onboarding', {'skipped': true});
      await client.put('/me/notification-preferences', {'polls': false});
      await client.patch('/profiles/contributors/me', {'city': 'Yaba'});
      await client.delete('/wallet/bank-account');
      await client.send('POST', '/notifications/read', body: ['n_1']);

      expect(
        [for (final r in api.requests) '${r.method} ${r.url}'],
        [
          'GET https://api.test/me',
          'POST https://api.test/me/onboarding',
          'PUT https://api.test/me/notification-preferences',
          'PATCH https://api.test/profiles/contributors/me',
          'DELETE https://api.test/wallet/bank-account',
          'POST https://api.test/notifications/read',
        ],
      );
      expect(
        [for (final r in api.requests) r.body],
        [
          '',
          '{"skipped":true}',
          '{"polls":false}',
          '{"city":"Yaba"}',
          '',
          '["n_1"]',
        ],
      );
      expect(
        api.requests[1].headers['content-type'],
        startsWith('application/json'),
      );
      expect(api.requests.first.headers.containsKey('content-type'), isFalse);
      expect(api.requests[4].headers.containsKey('content-type'), isFalse);
    });

    test('a write without a body sends an empty object', () async {
      final api = _Api();
      final client = _client(api.client);
      await client.post('/me/account/restore');
      await client.put('/me/notification-preferences');
      expect([for (final r in api.requests) r.body], ['{}', '{}']);
    });
  });

  group('headers', () {
    test('every request names the app, its version and the platform', () async {
      final api = _Api();
      await _client(api.client, platform: 'ios').get('/health');
      final headers = api.last.headers;
      expect(headers['accept'], 'application/json');
      expect(headers['x-iqly-client'], 'mobile');
      expect(headers['x-app'], 'web');
      expect(headers['x-app-version'], '0.3.1+4');
      expect(headers['x-platform'], 'ios');
      expect(headers.containsKey('authorization'), isFalse);
      expect(headers.containsKey('idempotency-key'), isFalse);
    });

    test('the platform is the one the app runs on', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final api = _Api();
      await _client(api.client).get('/health');
      expect(api.last.headers['x-platform'], 'ios');

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _client(api.client).get('/health');
      expect(api.last.headers['x-platform'], 'android');
    });

    test('no version known, no version header', () async {
      final api = _Api();
      await _client(api.client, appVersion: null).get('/health');
      expect(api.last.headers.containsKey('x-app-version'), isFalse);
    });

    test('the session token goes as a bearer token', () async {
      final api = _Api();
      await _client(api.client, token: 'abc.signed').get('/me');
      expect(api.last.headers['authorization'], 'Bearer abc.signed');
    });

    test('a write can carry an idempotency key', () async {
      final api = _Api();
      await _client(api.client).send(
        'POST',
        '/wallet/withdrawals',
        body: {'amount': 1000000},
        idempotencyKey: 'f2b9c0de-5d1e-4c7a-9a43-2c1b8e0f6a10',
      );
      expect(
        api.last.headers['idempotency-key'],
        'f2b9c0de-5d1e-4c7a-9a43-2c1b8e0f6a10',
      );
      expect(api.last.body, '{"amount":1000000}');
    });
  });

  group('answers', () {
    test('a list payload reads as a list, and data stays a map', () async {
      final api = _Api(
        (_) => _json(200, {
          'success': true,
          'data': [
            {'id': 'n_1'},
            {'id': 'n_2'},
          ],
        }),
      );
      final res = await _client(api.client).get('/banks');
      expect(res.ok, isTrue);
      expect(res.list, [
        {'id': 'n_1'},
        {'id': 'n_2'},
      ]);
      expect(res.data, isEmpty);
    });

    test('an object payload reads as data, with an empty list', () async {
      final api = _Api(
        (_) => _json(200, {
          'success': true,
          'data': {'available': 1250000},
        }),
      );
      final res = await _client(api.client).get('/wallet');
      expect(res.data, {'available': 1250000});
      expect(res.list, isEmpty);
    });

    test('a body that is not JSON reads as empty', () async {
      final api = _Api((_) => http.Response('<html>Bad gateway</html>', 502));
      final res = await _client(api.client).get('/health');
      expect(res.ok, isFalse);
      expect(res.body, isEmpty);
      expect(res.data, isEmpty);
      expect(res.list, isEmpty);
      expect(res.code, isNull);
      expect(res.message, isNull);
    });

    test('an API error gives its code and message', () async {
      final api = _Api(
        (_) => _json(409, {
          'success': false,
          'error': {
            'code': 'PROFILE_INCOMPLETE',
            'message': 'Add your date of birth first.',
            'details': {
              'missing': ['dateOfBirth'],
            },
          },
        }),
      );
      final res = await _client(api.client).post('/wallet/withdrawals');
      expect(res.code, 'PROFILE_INCOMPLETE');
      expect(res.message, 'Add your date of birth first.');
    });

    test('a Better Auth error gives its code and message', () async {
      final api = _Api(
        (_) => _json(401, {
          'code': 'INVALID_EMAIL_OR_PASSWORD',
          'message': 'Invalid email or password',
        }),
      );
      final res = await _client(api.client).post('/auth/web/sign-in/email');
      expect(res.code, 'INVALID_EMAIL_OR_PASSWORD');
      expect(res.message, 'Invalid email or password');
    });

    test('a 429 says how long to wait', () async {
      final api = _Api(
        (_) => _json(
          429,
          {
            'success': false,
            'error': {'code': 'RATE_LIMITED', 'message': 'Slow down'},
          },
          headers: {'retry-after': '30'},
        ),
      );
      final res = await _client(api.client).post('/submissions/challenges/c1');
      expect(res.code, 'RATE_LIMITED');
      expect(res.retryAfter, const Duration(seconds: 30));

      api.answer = (_) => _json(429, {}, headers: {'retry-after': 'soon'});
      expect((await _client(api.client).get('/banks')).retryAfter, isNull);
      api.answer = (_) => _json(200, {});
      expect((await _client(api.client).get('/banks')).retryAfter, isNull);
    });
  });

  group('multipart', () {
    const files = [
      ApiFile(
        field: 'file',
        filename: 'sketch.png',
        bytes: [137, 80, 78, 71],
        contentType: 'image/png',
      ),
      ApiFile(
        field: 'file',
        filename: 'deck.pdf',
        bytes: [37, 80, 68, 70],
        contentType: 'application/pdf',
      ),
    ];

    test('sends the fields and files, with the usual headers', () async {
      final api = _Api((_) => _json(200, {'success': true, 'data': {}}));
      await _client(api.client, token: 'abc.signed').multipart(
        '/submissions/challenges/c1',
        fields: {'title': 'Sunday is data day', 'body': 'Plain text'},
        files: files,
        idempotencyKey: 'k-1',
      );
      final request = api.last;
      expect(request.method, 'POST');
      expect(request.url.path, '/submissions/challenges/c1');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      expect(request.headers['idempotency-key'], 'k-1');
      expect(request.headers['authorization'], 'Bearer abc.signed');
      expect(request.headers['x-app-version'], '0.3.1+4');
      final body = latin1.decode(request.bodyBytes);
      expect(body, contains('name="title"\r\n\r\nSunday is data day'));
      expect(body, contains('name="body"\r\n\r\nPlain text'));
      expect(
        body,
        contains(
          'content-type: image/png\r\n'
          'content-disposition: form-data; name="file"; '
          'filename="sketch.png"',
        ),
      );
      expect(body, contains('filename="deck.pdf"'));
      expect(body, contains('content-type: application/pdf'));
    });

    test('progress runs from 0 to 1 as the body is read', () async {
      final big = ApiFile(
        field: 'file',
        filename: 'photo.jpg',
        bytes: List.filled(200000, 7),
        contentType: 'image/jpeg',
      );
      final seen = <double>[];
      final readAt = <double>[];
      final client = MockClient.streaming((request, body) async {
        await for (final _ in body) {
          readAt.add(seen.last);
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"success":true,"data":{}}')),
          200,
        );
      });
      final res = await _client(client).multipart(
        '/submissions/challenges/c1',
        fields: {'title': 'Photo'},
        files: [big],
        onProgress: seen.add,
      );
      expect(res.ok, isTrue);
      expect(seen.first, 0);
      expect(seen.last, 1.0);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
      }
      expect(seen.where((p) => p > 0.1 && p < 0.9), hasLength(2));
      expect(readAt, seen.skip(1).toList());
    });

    test('a slow upload that keeps moving is never cut off', () {
      fakeAsync((async) {
        final client = MockClient.streaming((request, body) async {
          await for (final _ in body) {
            await Future<void>.delayed(const Duration(seconds: 15));
          }
          return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
        });
        ApiResponse? res;
        _client(client)
            .multipart(
              '/submissions/challenges/c1',
              fields: {'a': '1', 'b': '2', 'c': '3'},
              files: files,
            )
            .then((r) => res = r);
        async.elapse(const Duration(minutes: 10));
        expect(res?.status, 200);
      });
    });

    test('an upload that stops moving gives up after the timeout', () {
      fakeAsync((async) {
        final client = MockClient.streaming((request, body) async {
          body.listen((_) {}).pause();
          return Completer<http.StreamedResponse>().future;
        });
        Object? error;
        _client(client)
            .multipart(
              '/submissions/challenges/c1',
              fields: {'a': '1'},
              files: files,
            )
            .catchError((Object e) {
              error = e;
              return const ApiResponse(0, {});
            });
        async.elapse(const Duration(seconds: 19));
        expect(error, isNull);
        async.elapse(const Duration(seconds: 2));
        expect(error, isA<ApiUnreachable>());
      });
    });
  });

  group('a lost session', () {
    test('fires for a 401 to the session token', () async {
      final api = _Api((_) => _json(401, {'success': false}));
      final client = _client(api.client, token: 'abc.signed');
      var fired = 0;
      client.unauthorized.listen((_) => fired++);
      final res = await client.get('/me');
      await Future<void>.delayed(Duration.zero);
      expect(res.status, 401);
      expect(fired, 1);
    });

    test('stays quiet for Better Auth, a request without a token, or any '
        'other status', () async {
      final api = _Api(
        (_) => _json(401, {'code': 'INVALID_EMAIL_OR_PASSWORD'}),
      );
      final signedIn = _client(api.client, token: 'abc.signed');
      final signedOut = _client(api.client);
      var fired = 0;
      signedIn.unauthorized.listen((_) => fired++);
      signedOut.unauthorized.listen((_) => fired++);

      await signedIn.post('/auth/web/sign-in/email', {'email': 'a@b.co'});
      await signedIn.get('/auth/web/get-session');
      await signedOut.get('/me');
      api.answer = (_) => _json(403, {
        'success': false,
        'error': {'code': 'ACCOUNT_CLOSING'},
      });
      await signedIn.post('/wallet/withdrawals', {'amount': 100});
      await Future<void>.delayed(Duration.zero);
      expect(fired, 0);
    });

    test(
      'stays quiet when the token changed while the request was out',
      () async {
        final tokens = MemoryTokenStore('old.token');
        final client = _client(
          MockClient((request) async {
            await tokens.write('new.token');
            return _json(401, {'success': false});
          }),
          tokens: tokens,
        );
        var fired = 0;
        client.unauthorized.listen((_) => fired++);
        await client.get('/me');
        await Future<void>.delayed(Duration.zero);
        expect(fired, 0);
      },
    );

    test('fires for a multipart upload too', () async {
      final api = _Api((_) => _json(401, {'success': false}));
      final client = _client(api.client, token: 'abc.signed');
      var fired = 0;
      client.unauthorized.listen((_) => fired++);
      await client.multipart('/submissions/challenges/c1', fields: {'a': '1'});
      await Future<void>.delayed(Duration.zero);
      expect(fired, 1);
    });
  });

  test('no connection is unreachable', () async {
    final client = _client(
      MockClient((_) => throw http.ClientException('no route')),
    );
    await expectLater(client.get('/me'), throwsA(isA<ApiUnreachable>()));
    await expectLater(
      client.multipart('/submissions/challenges/c1', fields: {'a': '1'}),
      throwsA(isA<ApiUnreachable>()),
    );
  });

  group('every transport failure is unreachable', () {
    Matcher unreachable({required bool nothingSent}) => throwsA(
      isA<ApiUnreachable>().having(
        (e) => e.nothingSent,
        'nothingSent',
        nothingSent,
      ),
    );

    Future<void> failing(Object error, {required bool nothingSent}) async {
      final client = _client(MockClient((_) async => throw error));
      await expectLater(
        client.get('/challenges/browse'),
        unreachable(nothingSent: nothingSent),
        reason: '$error',
      );
      await expectLater(
        client.multipart('/submissions/challenges/c1', fields: {'a': '1'}),
        unreachable(nothingSent: nothingSent),
        reason: '$error',
      );
    }

    test(
      'TLS: a captive portal, a proxy that intercepts, a wrong clock',
      () async {
        await failing(
          const HandshakeException('WRONG_VERSION_NUMBER'),
          nothingSent: true,
        );
        await failing(
          const CertificateException('CERTIFICATE_VERIFY_FAILED'),
          nothingSent: false,
        );
        await failing(const TlsException('bad record mac'), nothingSent: false);
      },
    );

    test('a lookup or a connection that failed sent nothing', () async {
      await failing(
        const SocketException("Failed host lookup: 'api.iqly.net'"),
        nothingSent: true,
      );
      await failing(
        const SocketException(
          'Connection failed',
          osError: OSError('Connection refused', 111),
        ),
        nothingSent: true,
      );
    });

    test('a connection lost on the way may have sent the request', () async {
      await failing(
        const SocketException(
          'Connection reset by peer',
          osError: OSError('Connection reset by peer', 104),
        ),
        nothingSent: false,
      );
      await failing(
        const HttpException('Connection closed before full header'),
        nothingSent: false,
      );
      await failing(
        http.ClientException('Connection closed before full header'),
        nothingSent: false,
      );
    });

    test('a timeout may have sent the request', () {
      fakeAsync((async) {
        Object? error;
        _client(MockClient((_) => Completer<http.Response>().future))
            .get('/me')
            .catchError((Object e) {
              error = e;
              return const ApiResponse(0, {});
            });
        async.elapse(const Duration(seconds: 20));
        expect(error, isA<ApiUnreachable>());
        expect((error! as ApiUnreachable).nothingSent, isFalse);
      });
    });
  });
}
