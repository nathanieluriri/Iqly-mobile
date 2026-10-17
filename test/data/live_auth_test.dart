import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/auth.dart';
import 'package:iqly_mobile/data/live_auth.dart';
import 'package:iqly_mobile/data/token_store.dart';

class _Social implements SocialIdentity {
  _Social([this.token]);

  final SocialToken? token;
  bool signedOut = false;

  @override
  bool offers(AuthProvider provider) => true;

  @override
  Future<SocialToken?> signIn(AuthProvider provider) async => token;

  @override
  Future<void> signOut() async => signedOut = true;
}

/// A stand-in API: [routes] answer by "METHOD /path"; every request is kept.
class _Api {
  _Api(this.routes);

  final Map<String, (int, Object, Map<String, String>)> routes;
  final requests = <http.Request>[];

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final key = '${request.method} ${request.url.path}';
    final (status, body, headers) =
        routes[key] ?? (404, {'code': 'NOT_FOUND'}, const <String, String>{});
    return http.Response(jsonEncode(body), status, headers: headers);
  });

  Map<String, dynamic> body(String path) =>
      jsonDecode(requests.lastWhere((r) => r.url.path == path).body)
          as Map<String, dynamic>;
}

const _signed = 'abc.signed';
const _issued = {'set-auth-token': _signed};
const _profileNew = (404, {'success': false}, <String, String>{});
const _profileDone = (
  200,
  {
    'success': true,
    'data': {'onboardingCompletedAt': '2026-10-01T10:00:00Z'},
  },
  <String, String>{},
);

(LiveAuthService, MemoryTokenStore) _service(_Api api, [_Social? social]) {
  final tokens = MemoryTokenStore();
  return (
    LiveAuthService(
      api: ApiClient(
        tokens: tokens,
        client: api.client,
        baseUrl: 'https://api.test',
      ),
      social: social ?? _Social(),
    ),
    tokens,
  );
}

void main() {
  test(
    'every request says it is the mobile app and the web auth app',
    () async {
      final api = _Api({
        'POST /mobile/email-status': (
          200,
          {
            'success': true,
            'data': {'exists': true},
          },
          const {},
        ),
      });
      final (auth, _) = _service(api);
      final result = await auth.lookUpEmail('ada@example.com');
      expect(result.ok, isTrue);
      expect(result.newAccount, isFalse);
      final headers = api.requests.single.headers;
      expect(headers['x-iqly-client'], 'mobile');
      expect(headers['x-app'], 'web');
      expect(headers.containsKey('authorization'), isFalse);
    },
  );

  test('a new email looks new', () async {
    final api = _Api({
      'POST /mobile/email-status': (
        200,
        {
          'success': true,
          'data': {'exists': false},
        },
        const {},
      ),
    });
    final (auth, _) = _service(api);
    expect((await auth.lookUpEmail('new@example.com')).newAccount, isTrue);
  });

  test('sign up makes the account and emails the code', () async {
    final api = _Api({
      'POST /auth/web/sign-up/email': (200, {'token': null}, const {}),
      'POST /auth/web/email-otp/send-verification-otp': (
        200,
        {'success': true},
        const {},
      ),
    });
    final (auth, tokens) = _service(api);
    final result = await auth.signUp(
      firstName: 'Ada',
      lastName: 'Obi',
      email: ' ada@example.com ',
      password: 'boldthinker',
    );
    expect(result.ok, isTrue);
    expect(api.body('/auth/web/sign-up/email'), {
      'name': 'Ada Obi',
      'email': 'ada@example.com',
      'password': 'boldthinker',
    });
    expect(api.body('/auth/web/email-otp/send-verification-otp'), {
      'email': 'ada@example.com',
      'type': 'email-verification',
    });
    expect(await tokens.read(), isNull);
  });

  test('the code signs in with the signed token from the header', () async {
    final api = _Api({
      'POST /auth/web/email-otp/verify-email': (
        200,
        {'status': true, 'token': 'raw'},
        _issued,
      ),
      'GET /profiles/contributors/me': _profileNew,
    });
    final (auth, tokens) = _service(api);
    final result = await auth.verifyEmail(
      email: 'ada@example.com',
      code: '482915',
    );
    expect(result.ok, isTrue);
    expect(result.newAccount, isTrue);
    expect(await tokens.read(), _signed);
    expect(api.requests.last.headers['authorization'], 'Bearer $_signed');
  });

  final codeFailures = {
    'INVALID_OTP': AuthFailure.wrongCode,
    'OTP_EXPIRED': AuthFailure.codeExpired,
    'TOO_MANY_ATTEMPTS': AuthFailure.tooManyAttempts,
  };
  for (final MapEntry(key: code, value: failure) in codeFailures.entries) {
    test('$code is $failure', () async {
      final api = _Api({
        'POST /auth/web/email-otp/verify-email': (
          code == 'TOO_MANY_ATTEMPTS' ? 403 : 400,
          {'code': code, 'message': code},
          const {},
        ),
      });
      final (auth, _) = _service(api);
      final result = await auth.verifyEmail(email: 'a@b.co', code: '000000');
      expect(result.failure, failure);
    });
  }

  test('a returning account signs in past onboarding', () async {
    final api = _Api({
      'POST /auth/web/sign-in/email': (200, {'token': 'raw'}, _issued),
      'GET /profiles/contributors/me': _profileDone,
    });
    final (auth, _) = _service(api);
    final result = await auth.signIn(email: 'ada@example.com', password: 'x');
    expect(result.ok, isTrue);
    expect(result.newAccount, isFalse);
  });

  final signInFailures = {
    (401, 'INVALID_EMAIL_OR_PASSWORD'): AuthFailure.wrongCredentials,
    (403, 'EMAIL_NOT_VERIFIED'): AuthFailure.emailNotVerified,
    (429, null): AuthFailure.tooManyAttempts,
    (500, null): AuthFailure.unknown,
  };
  for (final MapEntry(key: (status, code), value: failure)
      in signInFailures.entries) {
    test('sign in answering $status ${code ?? ''} is $failure', () async {
      final api = _Api({
        'POST /auth/web/sign-in/email': (status, {'code': ?code}, const {}),
      });
      final (auth, tokens) = _service(api);
      final result = await auth.signIn(email: 'a@b.co', password: 'x');
      expect(result.failure, failure);
      expect(await tokens.read(), isNull);
    });
  }

  test('no connection is offline', () async {
    final tokens = MemoryTokenStore();
    final auth = LiveAuthService(
      api: ApiClient(
        tokens: tokens,
        client: MockClient((_) => throw http.ClientException('no route')),
      ),
      social: _Social(),
    );
    expect(
      (await auth.signIn(email: 'a@b.co', password: 'x')).failure,
      AuthFailure.offline,
    );
  });

  test('a TLS failure is offline too, never an error that escapes', () async {
    final auth = LiveAuthService(
      api: ApiClient(
        tokens: MemoryTokenStore(),
        client: MockClient(
          (_) => throw const HandshakeException('WRONG_VERSION_NUMBER'),
        ),
      ),
      social: _Social(),
    );
    expect(
      (await auth.signIn(email: 'a@b.co', password: 'x')).failure,
      AuthFailure.offline,
    );
    expect((await auth.lookUpEmail('a@b.co')).failure, AuthFailure.offline);
  });

  test('Apple sends its ID token, nonce and first-time name', () async {
    final api = _Api({
      'POST /auth/web/sign-in/social': (200, {'redirect': false}, _issued),
      'GET /profiles/contributors/me': _profileNew,
    });
    final (auth, tokens) = _service(
      api,
      _Social(
        const SocialToken(
          'apple.jwt',
          nonce: 'hashed',
          firstName: 'Ada',
          lastName: 'Obi',
        ),
      ),
    );
    final result = await auth.continueWith(AuthProvider.apple);
    expect(result.newAccount, isTrue);
    expect(api.body('/auth/web/sign-in/social'), {
      'provider': 'apple',
      'idToken': {
        'token': 'apple.jwt',
        'nonce': 'hashed',
        'user': {
          'name': {'firstName': 'Ada', 'lastName': 'Obi'},
        },
      },
    });
    expect(await tokens.read(), _signed);
  });

  test('Google sends the bare ID token', () async {
    final api = _Api({
      'POST /auth/web/sign-in/social': (200, {'redirect': false}, _issued),
      'GET /profiles/contributors/me': _profileDone,
    });
    final (auth, _) = _service(api, _Social(const SocialToken('google.jwt')));
    final result = await auth.continueWith(AuthProvider.google);
    expect(result.newAccount, isFalse);
    expect(api.body('/auth/web/sign-in/social'), {
      'provider': 'google',
      'idToken': {'token': 'google.jwt'},
    });
  });

  test(
    'closing the Apple or Google sheet is cancelled, with no call',
    () async {
      final api = _Api({});
      final (auth, _) = _service(api, _Social());
      expect(
        (await auth.continueWith(AuthProvider.google)).failure,
        AuthFailure.cancelled,
      );
      expect(api.requests, isEmpty);
    },
  );

  test('sign out forgets the token even offline', () async {
    final social = _Social();
    final tokens = MemoryTokenStore(_signed);
    final auth = LiveAuthService(
      api: ApiClient(
        tokens: tokens,
        client: MockClient((_) => throw http.ClientException('no route')),
      ),
      social: social,
    );
    await auth.signOut();
    expect(await tokens.read(), isNull);
    expect(social.signedOut, isTrue);
  });
}
