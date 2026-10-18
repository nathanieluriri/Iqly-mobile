import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/session.dart';
import 'api_client.dart';
import 'live/live_account.dart' show apiInt, apiText, apiTime;
import 'live/live_repository.dart';

/// `GET /wallet/pin` (contract 13.1).
class PinStatus {
  const PinStatus({
    this.set = false,
    this.locked = false,
    this.lockedUntil,
    this.resetRequired = false,
    this.attemptsLeft,
  });

  factory PinStatus.fromJson(Map<String, dynamic> json) => PinStatus(
    set: json['set'] == true,
    locked: json['locked'] == true,
    lockedUntil: apiTime(json['lockedUntil']),
    resetRequired: json['resetRequired'] == true,
    attemptsLeft: apiInt(json['attemptsLeft']),
  );

  final bool set;
  final bool locked;
  final DateTime? lockedUntil;

  /// The third lock in a row: only a reset by emailed code opens it.
  final bool resetRequired;
  final int? attemptsLeft;
}

/// An emailed code on its way: where it went and when another can go.
class PinCodeSent {
  const PinCodeSent({required this.sentTo, this.resendAt});

  final String sentTo;
  final DateTime? resendAt;
}

enum PinProblem {
  /// 403 PIN_INCORRECT, with [PinRefused.attemptsLeft].
  incorrect,

  /// 423 PIN_LOCKED, with [PinRefused.retryAfter].
  locked,

  /// 423 PIN_RESET_REQUIRED: only a reset by emailed code opens it.
  resetRequired,

  /// 403 PIN_REQUIRED: a withdrawal sent without the PIN once one is set.
  required,
  notSet,
  alreadySet,
  passwordIncorrect,

  /// The account signs in with Google or Apple only, so it uses the code.
  passwordNotSet,

  /// 400 CODE_INVALID, with [PinRefused.attemptsLeft].
  codeInvalid,
  codeExpired,

  /// 429, with [PinRefused.retryAfter].
  rateLimited,
  closing,
  offline,
  unknown,
}

/// Why a PIN call did not go through.
class PinRefused implements Exception {
  const PinRefused(this.problem, {this.attemptsLeft, this.retryAfter});

  /// Reads the API's code, its `details` and its Retry-After.
  factory PinRefused.of(ApiResponse res) {
    final error = res.body['error'];
    final details = error is Map && error['details'] is Map
        ? (error['details'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final seconds = apiInt(details['retryAfterSeconds']);
    return PinRefused(
      problemOf(res.status, res.code),
      attemptsLeft: apiInt(details['attemptsLeft']),
      retryAfter:
          res.retryAfter ??
          (seconds == null ? null : Duration(seconds: seconds)),
    );
  }

  static PinProblem problemOf(int status, String? code) => switch (code) {
    'PIN_INCORRECT' => PinProblem.incorrect,
    'PIN_LOCKED' => PinProblem.locked,
    'PIN_RESET_REQUIRED' => PinProblem.resetRequired,
    'PIN_REQUIRED' => PinProblem.required,
    'PIN_NOT_SET' => PinProblem.notSet,
    'PIN_ALREADY_SET' => PinProblem.alreadySet,
    'PIN_PASSWORD_INCORRECT' => PinProblem.passwordIncorrect,
    'PIN_PASSWORD_NOT_SET' => PinProblem.passwordNotSet,
    'CODE_INVALID' => PinProblem.codeInvalid,
    'CODE_EXPIRED' => PinProblem.codeExpired,
    'ACCOUNT_CLOSING' => PinProblem.closing,
    _ when status == 429 => PinProblem.rateLimited,
    _ => PinProblem.unknown,
  };

  final PinProblem problem;
  final int? attemptsLeft;
  final Duration? retryAfter;

  @override
  String toString() => 'PinRefused(${problem.name})';
}

/// The withdrawal PIN on the API (contract 13.1). The PIN only ever goes
/// in a request body: the phone never keeps it, logs it or reads it back.
class PinService {
  PinService(this.api, {AccountScope? scope})
    : scope = scope ?? AccountScope.always();

  final ApiClient api;
  final AccountScope scope;

  Future<PinStatus> status() async =>
      PinStatus.fromJson(_data(await _call(() => api.get('/wallet/pin'))));

  Future<PinCodeSent> sendCode() async {
    final data = _data(await _call(() => api.post('/wallet/pin/code')));
    return PinCodeSent(
      sentTo: apiText(data['sentTo']) ?? '',
      resendAt: apiTime(data['resendAt']),
    );
  }

  /// The first PIN, proved by an emailed [code] or the account's
  /// [password].
  Future<PinStatus> create(String pin, {String? code, String? password}) =>
      _status(
        () => api.post('/wallet/pin', {
          'pin': pin,
          'code': ?code,
          'password': ?password,
        }),
      );

  Future<PinStatus> change(String currentPin, String pin) => _status(
    () => api.put('/wallet/pin', {'currentPin': currentPin, 'pin': pin}),
  );

  /// Sets a new PIN with an emailed code, with or without one before, and
  /// lifts any lock.
  Future<PinStatus> reset(String code, String pin) =>
      _status(() => api.post('/wallet/pin/reset', {'code': code, 'pin': pin}));

  Future<void> verify(String pin) async {
    await _call(() => api.post('/wallet/pin/verify', {'pin': pin}));
  }

  Future<PinStatus> _status(Future<ApiResponse> Function() send) async =>
      PinStatus.fromJson(_data(await _call(send)));

  Future<ApiResponse> _call(Future<ApiResponse> Function() send) async {
    final ApiResponse res;
    try {
      res = await scope.guard(send());
    } on ApiUnreachable {
      throw const PinRefused(PinProblem.offline);
    }
    if (!res.ok) throw PinRefused.of(res);
    return res;
  }

  static Map<String, dynamic> _data(ApiResponse res) => res.data;
}

/// The PIN while the API runs it, for the signed-in person; null in the
/// preview and while `withdrawalPin` is off, which asks for no PIN live.
final pinServiceProvider = Provider<PinService?>((ref) {
  final api = ref.watch(apiClientProvider);
  final mode = ref.watch(liveModeProvider);
  if (api == null || !mode.isLive(LiveFeature.withdrawalPin)) return null;
  return PinService(api, scope: ref.watch(accountScopeProvider));
});

/// Whether the person has a PIN, and its lock, read afresh on each visit.
final pinStatusProvider = FutureProvider.autoDispose<PinStatus?>(
  retry: (_, _) => null,
  (ref) async => ref.watch(pinServiceProvider)?.status(),
);
