import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/session.dart';
import 'api_client.dart';
import 'live/live_account.dart' show apiText;
import 'live/live_repository.dart';

/// `GET /me/kyc`. Dojah has matched the name, or it has not.
class KycStatus {
  const KycStatus({
    this.required = false,
    this.verified = false,
    this.method,
    this.last4,
  });

  factory KycStatus.fromJson(Map<String, dynamic> json) {
    final method = json['method'];
    return KycStatus(
      required: json['required'] == true,
      verified: json['verified'] == true,
      method: method == 'bvn'
          ? KycMethod.bvn
          : method == 'nin'
          ? KycMethod.nin
          : null,
      last4: apiText(json['last4']),
    );
  }

  /// False until both Dojah keys are set. Withdrawals are not gated before that.
  final bool required;
  final bool verified;
  final KycMethod? method;
  final String? last4;

  bool get needsCheck => required && !verified;
}

enum KycMethod { nin, bvn }

/// The name and the 11 digit NIN or BVN sent to Dojah.
class KycCheck {
  const KycCheck({
    required this.method,
    required this.number,
    required this.firstName,
    required this.lastName,
    this.dob,
  });

  final KycMethod method;
  final String number;
  final String firstName;
  final String lastName;
  final String? dob;
}

enum KycProblem {
  mismatch,
  unavailable,
  notConfigured,
  invalid,
  offline,
  unknown,
}

class KycRefused implements Exception {
  const KycRefused(this.problem, {this.message});

  factory KycRefused.of(ApiResponse res) => KycRefused(switch (res.code) {
    'KYC_MISMATCH' => KycProblem.mismatch,
    'KYC_UNAVAILABLE' => KycProblem.unavailable,
    'KYC_NOT_CONFIGURED' => KycProblem.notConfigured,
    'VALIDATION_ERROR' => KycProblem.invalid,
    _ => KycProblem.unknown,
  }, message: res.message);

  final KycProblem problem;
  final String? message;

  @override
  String toString() => 'KycRefused(${problem.name})';
}

/// Name match on an NIN or BVN, before the first withdrawal.
class KycService {
  KycService(this.api, {AccountScope? scope})
    : scope = scope ?? AccountScope.always();

  final ApiClient api;
  final AccountScope scope;

  Future<KycStatus> status() async =>
      KycStatus.fromJson((await _call(() => api.get('/me/kyc'))).data);

  Future<KycStatus> verify(KycCheck check) async => KycStatus.fromJson(
    (await _call(
      () => api.post('/me/kyc', {
        'method': check.method.name,
        'number': check.number,
        'firstName': check.firstName,
        'lastName': check.lastName,
        'dob': ?check.dob,
      }),
    )).data,
  );

  Future<ApiResponse> _call(Future<ApiResponse> Function() send) async {
    final ApiResponse res;
    try {
      res = await scope.guard(send());
    } on ApiUnreachable {
      throw const KycRefused(KycProblem.offline);
    }
    if (!res.ok) throw KycRefused.of(res);
    return res;
  }
}

/// Live withdrawals ask Dojah. Preview keeps the withdraw sheet as it was.
final kycServiceProvider = Provider<KycService?>((ref) {
  final api = ref.watch(apiClientProvider);
  final mode = ref.watch(liveModeProvider);
  if (api == null || mode.isPreview || !mode.isLive(LiveFeature.withdrawals)) {
    return null;
  }
  return KycService(api, scope: ref.watch(accountScopeProvider));
});

/// Words for a refused check.
String kycError(KycRefused refused) => switch (refused.problem) {
  KycProblem.mismatch => 'That name does not match this ID.',
  KycProblem.unavailable => 'The identity check did not complete. Try again.',
  KycProblem.notConfigured => 'Identity checks are not set up yet.',
  KycProblem.invalid => 'Check the number and your name.',
  KycProblem.offline => 'No connection. Try again.',
  KycProblem.unknown => refused.message ?? 'Couldn’t check that ID. Try again.',
};
