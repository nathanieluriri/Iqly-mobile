import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/local/local_providers.dart';
import 'package:iqly_mobile/data/local/local_store.dart';
import 'package:iqly_mobile/data/token_store.dart';

/// One request the fake API took, its JSON body decoded.
class ApiCall {
  const ApiCall(this.method, this.url, this.headers, this.body);

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Object? body;

  /// `PATCH /profiles/contributors/me`.
  String get route => '$method ${url.path}';
}

typedef ApiAnswer = FutureOr<http.Response> Function(ApiCall call);

/// The iQLY API as a test scripts it, through a real [ApiClient]: each
/// `METHOD /path` answers from [routes], anything else is a 404, and every
/// request lands in [calls]. While [offline] nothing answers at all.
class FakeApi {
  FakeApi([Map<String, ApiAnswer>? routes]) : routes = {...?routes};

  final Map<String, ApiAnswer> routes;
  final calls = <ApiCall>[];
  bool offline = false;
  final tokens = MemoryTokenStore('signed.token');

  late final client = ApiClient(
    tokens: tokens,
    baseUrl: 'https://api.test',
    client: MockClient(_answer),
  );

  Future<http.Response> _answer(http.Request request) async {
    final call = ApiCall(
      request.method,
      request.url,
      request.headers,
      request.body.isEmpty ? null : jsonDecode(request.body),
    );
    calls.add(call);
    if (offline) throw http.ClientException('offline');
    final answer = routes[call.route];
    if (answer == null) return refusal(404, 'NOT_FOUND');
    return answer(call);
  }

  /// The calls to [route], oldest first.
  List<ApiCall> to(String route) => [
    for (final call in calls)
      if (call.route == route) call,
  ];
}

http.Response _json(Object body, int status, [Map<String, String>? headers]) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8', ...?headers},
    );

/// `{success: true, data}`.
http.Response answer(Object? data, {int status = 200}) =>
    _json({'success': true, 'data': data}, status);

/// Better Auth's own shape, with no envelope.
http.Response raw(Object body, {Map<String, String>? headers}) =>
    _json(body, 200, headers);

/// `{success: false, error: {code, message}}`.
http.Response refusal(
  int status,
  String code, {
  String message = '',
  Map<String, String>? headers,
}) => _json(
  {
    'success': false,
    'error': {'code': code, 'message': message},
  },
  status,
  headers,
);

/// A launch fixed on [mode].
class FixedBackend extends BackendNotifier {
  FixedBackend(this.mode);

  final Backend mode;

  @override
  Backend build() => mode;
}

/// The features 0.4.0 shipped live, before contract section 10 added
/// avatar, saved bank accounts, the leaderboard and referrals.
const firstFeatures = {
  LiveFeature.profile,
  LiveFeature.briefs,
  LiveFeature.submit,
  LiveFeature.submissions,
  LiveFeature.wallet,
  LiveFeature.withdrawals,
  LiveFeature.notifications,
  LiveFeature.account,
};

/// Every feature 0.4.0 runs on the API.
final allLive = Backend.of(firstFeatures);

/// A live build on [api] in [mode] (everything live by default).
List<Override> liveOverrides(FakeApi api, {Backend? mode, LocalStore? store}) =>
    [
      apiClientProvider.overrideWithValue(api.client),
      backendProvider.overrideWith(() => FixedBackend(mode ?? allLive)),
      if (store != null) localStoreProvider.overrideWithValue(store),
    ];

/// The contributor profile answer (contract 3.2: the existing answer plus
/// `sector`, `sectorOther` and `interestOther`).
Map<String, Object?> profileJson({
  String? phone = '+2348012345678',
  String? dateOfBirth = '2001-04-09',
  String? onboardingCompletedAt = '2026-09-01T10:05:00.000Z',
}) => {
  'id': 'cp_1',
  'userId': 'u_1',
  'phone': phone,
  'dateOfBirth': dateOfBirth,
  'ageBand': '25-34',
  'gender': 'female',
  'country': 'NG',
  'stateOfOrigin': 'Anambra',
  'stateOfResidence': 'Lagos',
  'city': 'Yaba',
  'occupations': ['student'],
  'education': 'hnd_bsc',
  'university': 'University of Lagos',
  'interests': ['finance_fintech', 'marketing_advertising'],
  'heardAbout': null,
  'sector': null,
  'sectorOther': null,
  'interestOther': null,
  'termsAcceptedAt': '2026-09-01T10:00:00.000Z',
  'onboardingCompletedAt': onboardingCompletedAt,
  'createdAt': '2026-09-01T10:00:00.000Z',
  'updatedAt': '2026-09-01T10:05:00.000Z',
};

/// `GET /me` (contract 3).
Map<String, Object?> meJson({
  String status = 'active',
  String? closesAt,
  Object? profile = const {},
}) => {
  'id': 'u_1',
  'name': 'Ada Obi',
  'email': 'ada@example.com',
  'emailVerified': true,
  'memberSince': '2026-09-01T10:00:00.000Z',
  'status': status,
  'closesAt': closesAt,
  'profile': profile is Map && profile.isEmpty ? profileJson() : profile,
};
