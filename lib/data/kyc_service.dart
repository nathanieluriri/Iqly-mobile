import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session.dart';
import '../features/kyc/kyc_status.dart';
import 'api_client.dart';

export '../features/kyc/kyc_status.dart';

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

class KycEvidence {
  const KycEvidence({
    required this.filename,
    required this.bytes,
    required this.contentType,
  });

  final String filename;
  final List<int> bytes;
  final String contentType;
}

enum KycProblem {
  mismatch,
  unavailable,
  review,
  failed,
  invalid,
  offline,
  unknown,
}

class KycRefused implements Exception {
  const KycRefused(this.problem, {this.message});

  factory KycRefused.of(ApiResponse res) => KycRefused(switch (res.code) {
    'KYC_MISMATCH' => KycProblem.mismatch,
    'KYC_REVIEW' || 'KYC_PENDING' => KycProblem.review,
    'KYC_FAILED' => KycProblem.failed,
    'KYC_NOT_CONFIGURED' || 'KYC_UNAVAILABLE' => KycProblem.unavailable,
    'VALIDATION_ERROR' => KycProblem.invalid,
    _ => res.status >= 500 ? KycProblem.unavailable : KycProblem.unknown,
  }, message: res.message);

  final KycProblem problem;
  final String? message;

  @override
  String toString() => 'KycRefused(${problem.name})';
}

/// API-only progressive contributor verification.
abstract class KycService {
  factory KycService(
    ApiClient api, {
    AccountScope? scope,
    String Function()? newKey,
  }) => ApiKycService(api, scope: scope, newKey: newKey);

  Future<KycStatus> status();
  Future<KycStatus> verify(KycCheck check);
  Future<KycStatus> upload(KycCheckKind check, KycEvidence file);
}

class ApiKycService implements KycService {
  ApiKycService(this.api, {AccountScope? scope, String Function()? newKey})
    : scope = scope ?? AccountScope.always(),
      newKey = newKey ?? _newKey;

  final ApiClient api;
  final AccountScope scope;
  final String Function() newKey;
  KycCheck? _verifyAttempt;
  String? _verifyKey;
  KycCheckKind? _uploadCheck;
  KycEvidence? _uploadAttempt;
  String? _uploadKey;

  String _keyForVerify(KycCheck check) {
    final previous = _verifyAttempt;
    if (previous == null ||
        previous.method != check.method ||
        previous.number != check.number ||
        previous.firstName != check.firstName ||
        previous.lastName != check.lastName ||
        previous.dob != check.dob) {
      _verifyAttempt = check;
      _verifyKey = newKey();
    }
    return _verifyKey!;
  }

  String _keyForUpload(KycCheckKind check, KycEvidence file) {
    final previous = _uploadAttempt;
    if (_uploadCheck != check ||
        previous == null ||
        previous.filename != file.filename ||
        previous.contentType != file.contentType ||
        !listEquals(previous.bytes, file.bytes)) {
      _uploadCheck = check;
      _uploadAttempt = file;
      _uploadKey = newKey();
    }
    return _uploadKey!;
  }

  Future<KycStatus> status() async =>
      KycStatus.fromJson((await _call(() => api.get('/me/kyc'))).data);

  Future<KycStatus> verify(KycCheck check) async => KycStatus.fromJson(
    (await _call(
      () => api.send(
        'POST',
        '/me/kyc',
        idempotencyKey: _keyForVerify(check),
        body: {
          'method': check.method.name,
          'number': check.number,
          'firstName': check.firstName,
          'lastName': check.lastName,
          'dob': ?check.dob,
        },
      ),
    )).data,
  );

  Future<KycStatus> upload(KycCheckKind check, KycEvidence file) async {
    if (file.bytes.isEmpty) {
      throw const KycRefused(KycProblem.invalid, message: 'Choose a file.');
    }
    if (file.bytes.length > 10 * 1024 * 1024) {
      throw const KycRefused(
        KycProblem.invalid,
        message: 'File must be 10 MB or smaller.',
      );
    }
    const images = {'image/jpeg', 'image/png', 'image/webp'};
    final accepted = check == KycCheckKind.document
        ? {...images, 'application/pdf'}
        : images;
    if (!accepted.contains(file.contentType)) {
      throw const KycRefused(
        KycProblem.invalid,
        message: 'Unsupported file type.',
      );
    }
    final path = switch (check) {
      KycCheckKind.document => '/me/kyc/document',
      KycCheckKind.selfie => '/me/kyc/selfie',
      KycCheckKind.liveness => '/me/kyc/liveness',
      _ => throw const KycRefused(KycProblem.invalid),
    };
    return KycStatus.fromJson(
      (await _call(
        () => api.multipart(
          path,
          fields: const {},
          files: [
            ApiFile(
              field: check.name,
              filename: file.filename,
              bytes: file.bytes,
              contentType: file.contentType,
            ),
          ],
          idempotencyKey: _keyForUpload(check, file),
        ),
      )).data,
    );
  }

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

String _newKey() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Without an API there is no verification service to fall back from.
class UnavailableKycService implements KycService {
  @override
  Future<KycStatus> status() async =>
      throw const KycRefused(KycProblem.unavailable);

  @override
  Future<KycStatus> verify(KycCheck check) async =>
      throw const KycRefused(KycProblem.unavailable);

  @override
  Future<KycStatus> upload(KycCheckKind check, KycEvidence file) async =>
      throw const KycRefused(KycProblem.unavailable);
}

final kycServiceProvider = Provider<KycService>((ref) {
  final api = ref.watch(apiClientProvider);
  if (api == null) return UnavailableKycService();
  return KycService(api, scope: ref.watch(accountScopeProvider));
});

String kycError(KycRefused refused) => switch (refused.problem) {
  KycProblem.mismatch =>
    'That name does not match this ID. Check the name and the number.',
  KycProblem.unavailable => 'The identity check did not complete. Try again.',
  KycProblem.review => 'Your details are being reviewed. Check back soon.',
  KycProblem.failed => 'The check did not pass. Review your details and retry.',
  KycProblem.invalid => refused.message ?? 'Check the number and your name.',
  KycProblem.offline => 'No connection. Try again.',
  KycProblem.unknown => refused.message ?? 'Couldn’t check that ID. Try again.',
};
