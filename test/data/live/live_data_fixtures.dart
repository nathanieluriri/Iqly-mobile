import 'dart:convert';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iqly_mobile/core/backend.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/token_store.dart';

/// The iQLY API as a test scripts it: each `METHOD /path` answers as set,
/// anything else 404s, and every request is kept. [offline] makes every
/// request fail as a dropped connection does.
class FakeApi {
  final requests = <http.Request>[];
  final _routes = <String, http.Response Function(http.Request request)>{};
  bool offline = false;

  /// Answers `METHOD /path` (the query is not matched).
  void on(
    String method,
    String path,
    http.Response Function(http.Request request) answer,
  ) => _routes['$method $path'] = answer;

  /// Answers `METHOD /path` with `{success: true, data}`.
  void data(String method, String path, Object? data, {int status = 200}) =>
      on(method, path, (_) => ok(data, status: status));

  late final client = MockClient((request) async {
    requests.add(request);
    if (offline) throw http.ClientException('offline', request.url);
    final answer = _routes['${request.method} ${request.url.path}'];
    return answer?.call(request) ??
        refused(404, 'NOT_FOUND', 'Route not found.');
  });

  ApiClient api() => ApiClient(
    tokens: MemoryTokenStore('session.signed'),
    client: client,
    baseUrl: 'https://api.test',
    appVersion: '0.3.1+4',
    platform: 'android',
  );

  /// The requests made to [path], in order.
  List<http.Request> to(String path, {String? method}) => [
    for (final r in requests)
      if (r.url.path == path && (method == null || r.method == method)) r,
  ];
}

http.Response ok(Object? data, {int status = 200}) =>
    _json(status, {'success': true, 'data': data});

http.Response refused(
  int status,
  String code, [
  String message = 'Refused.',
  Map<String, String> headers = const {},
]) => _json(status, {
  'success': false,
  'error': {'code': code, 'message': message},
}, headers: headers);

http.Response _json(
  int status,
  Object body, {
  Map<String, String> headers = const {},
}) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8', ...headers},
);

/// This launch's mode, fixed.
class FixedBackend extends BackendNotifier {
  FixedBackend(this.mode);

  final Backend mode;

  @override
  Backend build() => mode;
}

/// Every feature live.
final allLive = Backend.of(LiveFeature.values);

/// The overrides that make a launch live on [api].
List<Override> liveOverrides(ApiClient api, {Backend? mode}) => [
  apiClientProvider.overrideWithValue(api),
  backendProvider.overrideWith(() => FixedBackend(mode ?? allLive)),
];

/// A cursor page of [items].
Map<String, Object?> page(List<Object?> items, [String? next]) => {
  'items': items,
  'nextCursor': next,
};

/// A public brief as `/challenges/browse` and `/challenges/:id` answer it
/// (contract section 4), with [change] laid over it.
Map<String, Object?> challengeJson([
  Map<String, Object?> change = const {},
]) => {
  'id': 'c_1',
  'slug': 'make-sunday-data-day',
  'title': 'Make Sunday data day',
  'overview': '<p>Most of our customers top up on Sundays.</p>',
  'problemStatement': '<p>What would make Sunday the day they buy data?</p>',
  'deliverables': ['One campaign idea', 'A line for the poster'],
  'successCriteria': ['Fits a small budget'],
  'successCriteriaWeights': <int>[],
  'coverImageUrl': 'challenges/c_1/cover.jpg',
  'tier': 'advanced',
  'category': 'customer_experience',
  'winnerConfig': {
    'type': 'top_n',
    'n': 3,
    'split': [60, 30, 10],
  },
  'rewardPool': 15000000,
  'maxSubmissions': 40,
  'audienceFilters': {
    'interests': ['finance_fintech', 'marketing_advertising'],
  },
  'audienceSurvey': {
    'questions': [
      {
        'id': 'q_lang',
        'q': 'Which language should lead?',
        'type': 'mcq',
        'options': ['English', 'Pidgin', 'Both, side by side'],
      },
      {
        'id': 'q_where',
        'q': 'Where do you buy data?',
        'type': 'mcq',
        'options': ['Bank app', 'USSD', 'Agent'],
        'multi': true,
      },
      {'id': 'q_why', 'q': 'Why Sunday?', 'type': 'subjective'},
    ],
  },
  'acceptedFormats': {'text': true, 'image': true, 'pdf': false},
  'displayBrandName': true,
  'status': 'live',
  'durationDays': 14,
  'deadline': '2026-10-24T17:00:00.000Z',
  'extendedDeadline': '2026-10-25T17:00:00.000Z',
  'effectiveDeadline': '2026-10-25T17:00:00.000Z',
  'judgingDeadline': '2026-11-01T17:00:00.000Z',
  'publishedAt': '2026-10-10T09:00:00.000Z',
  'createdAt': '2026-10-01T09:00:00.000Z',
  'updatedAt': '2026-10-10T09:00:00.000Z',
  'brandName': 'Kudi Box',
  'brandLogoUrl': 'https://api.test/profiles/brands/b_1/logo',
  'coverUrl': 'https://api.test/challenges/c_1/cover?v=1760086800000',
  'submissionCount': 12,
  'bodyText':
      'Most of our customers top up on Sundays.\n\n'
      'What would make Sunday the day they buy data?',
  'minutes': null,
  ...change,
};

/// A submission item (contract section 5), with [change] laid over it.
Map<String, Object?> submissionJson([Map<String, Object?> change = const {}]) =>
    {
      'id': 's_1',
      'challengeId': 'c_9',
      'title': 'Sunday is data day',
      'bodyText': 'Give a bonus bundle on Sundays.',
      'status': 'winner',
      'result': 'winner',
      'createdAt': '2026-09-20T10:00:00.000Z',
      'updatedAt': '2026-10-02T10:00:00.000Z',
      'files': [
        {
          'id': 'f_1',
          'type': 'image',
          'url': 'https://api.test/submissions/files/f_1',
        },
      ],
      'brief': {
        'id': 'c_9',
        'slug': 'a-closed-brief',
        'title': 'Why do people stop saving?',
        'businessName': 'Orchid Foods',
        'logoUrl': 'https://api.test/profiles/brands/b_9/logo',
        'coverUrl': 'https://api.test/challenges/c_9/cover?v=1',
        'deadline': '2026-09-30T17:00:00.000Z',
        'rewardPool': 25000000,
        'status': 'closed',
      },
      'award': {
        'amountKobo': 1250000,
        'awardedAt': '2026-10-02T10:00:00.000Z',
        'ledgerId': 't_1',
      },
      ...change,
    };

/// A wallet transaction (contract section 6), with [change] laid over it.
Map<String, Object?> transactionJson([
  Map<String, Object?> change = const {},
]) => {
  'id': 't_1',
  'contributorId': 'u_1',
  'amount': 1250000,
  'type': 'credit',
  'reference': 'p_1',
  'createdAt': '2026-10-02T10:00:00.000Z',
  'source': 'submission',
  'submissionId': 's_1',
  'challengeId': 'c_9',
  'challengeTitle': 'Why do people stop saving?',
  'businessName': 'Orchid Foods',
  'withdrawalId': null,
  'note': null,
  'referredName': null,
  ...change,
};

/// A withdrawal (contract section 6), with [change] laid over it.
Map<String, Object?> withdrawalJson([Map<String, Object?> change = const {}]) =>
    {
      'id': 'w_1',
      'contributorId': 'u_1',
      'amount': 1000000,
      'status': 'pending',
      'provider': 'paystack',
      'providerTransferReference': null,
      'failureReason': null,
      'reference': 'IQ-WD-261017-K7QM',
      'bankName': 'Access Bank',
      'accountLast4': '6789',
      'sentAt': null,
      'completedAt': null,
      'failedAt': null,
      'createdAt': '2026-10-17T08:00:00.000Z',
      'updatedAt': '2026-10-17T08:00:00.000Z',
      ...change,
    };

/// The payout account (contract section 6).
Map<String, Object?> bankAccountJson([
  Map<String, Object?> change = const {},
]) => {
  'id': 'ba_1',
  'bankCode': '044',
  'bankName': 'Access Bank',
  'accountLast4': '6789',
  'accountName': 'ADAEZE OKAFOR',
  'provider': 'paystack',
  'createdAt': '2026-09-01T10:00:00.000Z',
  'updatedAt': '2026-09-01T10:00:00.000Z',
  ...change,
};

/// `GET /wallet` (contract section 6).
Map<String, Object?> walletJson([Map<String, Object?> change = const {}]) => {
  'contributorId': 'u_1',
  'available': 2500000,
  'pendingWithdrawals': 1000000,
  'withdrawable': 1500000,
  'totalEarned': 6500000,
  'updatedAt': '2026-10-17T08:00:00.000Z',
  ...change,
};

final banksJson = [
  {'code': '044', 'name': 'Access Bank', 'currency': 'NGN'},
  {'code': '058', 'name': 'Guaranty Trust Bank', 'currency': 'NGN'},
];
