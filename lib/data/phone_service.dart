import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/session.dart';
import 'api_client.dart';
import 'live/live_account.dart' show apiInt, apiText, apiTime;
import 'live/live_repository.dart';

/// `GET /me/phone` and the verify answer (contract 13.2).
class PhoneStatus {
  const PhoneStatus({this.phone, this.verified = false, this.resendAt});

  factory PhoneStatus.fromJson(Map<String, dynamic> json) => PhoneStatus(
    phone: apiText(json['phone']),
    verified: json['verified'] == true,
    resendAt: apiTime(json['resendAt']),
  );

  final String? phone;
  final bool verified;
  final DateTime? resendAt;
}

/// A code on its way by SMS: the number in E.164 and when another can go.
class PhoneCodeSent {
  const PhoneCodeSent({required this.to, this.resendAt});

  final String to;
  final DateTime? resendAt;
}

enum PhoneProblem {
  /// 400 PHONE_INVALID: not a Nigerian mobile number.
  invalid,

  /// 409 PHONE_MISSING: no number given and none on the profile.
  missing,
  alreadyVerified,

  /// 502 SMS_SEND_FAILED: the SMS provider refused; asking again is fine.
  sendFailed,

  /// 503 SMS_NOT_CONFIGURED: no SMS on this API, so no code step.
  notConfigured,

  /// 429, with [PhoneRefused.retryAfter].
  rateLimited,

  /// 400 CODE_INVALID, with [PhoneRefused.attemptsLeft].
  codeInvalid,
  codeExpired,
  closing,
  offline,
  unknown,
}

class PhoneRefused implements Exception {
  const PhoneRefused(this.problem, {this.attemptsLeft, this.retryAfter});

  factory PhoneRefused.of(ApiResponse res) {
    final error = res.body['error'];
    final details = error is Map && error['details'] is Map
        ? (error['details'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final seconds = apiInt(details['retryAfterSeconds']);
    return PhoneRefused(
      switch (res.code) {
        'PHONE_INVALID' => PhoneProblem.invalid,
        'PHONE_MISSING' => PhoneProblem.missing,
        'PHONE_ALREADY_VERIFIED' => PhoneProblem.alreadyVerified,
        'SMS_SEND_FAILED' => PhoneProblem.sendFailed,
        'SMS_NOT_CONFIGURED' => PhoneProblem.notConfigured,
        'CODE_INVALID' => PhoneProblem.codeInvalid,
        'CODE_EXPIRED' => PhoneProblem.codeExpired,
        'ACCOUNT_CLOSING' => PhoneProblem.closing,
        _ when res.status == 429 => PhoneProblem.rateLimited,
        _ => PhoneProblem.unknown,
      },
      attemptsLeft: apiInt(details['attemptsLeft']),
      retryAfter:
          res.retryAfter ??
          (seconds == null ? null : Duration(seconds: seconds)),
    );
  }

  final PhoneProblem problem;
  final int? attemptsLeft;
  final Duration? retryAfter;

  @override
  String toString() => 'PhoneRefused(${problem.name})';
}

/// "Confirm your number" on the API: a 6-digit code by SMS.
class PhoneService {
  PhoneService(this.api, {AccountScope? scope})
    : scope = scope ?? AccountScope.always();

  final ApiClient api;
  final AccountScope scope;

  Future<PhoneStatus> status() async =>
      PhoneStatus.fromJson((await _call(() => api.get('/me/phone'))).data);

  /// To [phone] as typed, or to the profile's own number without one.
  Future<PhoneCodeSent> sendCode([String? phone]) async {
    final data = (await _call(
      () => api.post('/me/phone/code', {'phone': ?phone}),
    )).data;
    return PhoneCodeSent(
      to: apiText(data['to']) ?? phone ?? '',
      resendAt: apiTime(data['resendAt']),
    );
  }

  /// The right code saves the number it went to as the profile's phone,
  /// verified.
  Future<PhoneStatus> verify(String code) async => PhoneStatus.fromJson(
    (await _call(() => api.post('/me/phone/verify', {'code': code}))).data,
  );

  Future<ApiResponse> _call(Future<ApiResponse> Function() send) async {
    final ApiResponse res;
    try {
      res = await scope.guard(send());
    } on ApiUnreachable {
      throw const PhoneRefused(PhoneProblem.offline);
    }
    if (!res.ok) throw PhoneRefused.of(res);
    return res;
  }
}

/// The SMS code step while `phoneVerification` runs live; null otherwise,
/// which keeps the code page as it was.
final phoneServiceProvider = Provider<PhoneService?>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null ||
      !ref.watch(liveModeProvider).isLive(LiveFeature.phoneVerification)) {
    return null;
  }
  return PhoneService(api, scope: ref.watch(accountScopeProvider));
});
