import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/kyc_service.dart';
import 'package:iqly_mobile/features/kyc/kyc_status.dart';

import 'live/live_data_fixtures.dart';

Map<String, Object?> statusJson({
  bool required = true,
  bool verified = false,
  int tier = 1,
  int requiredTier = 2,
  String nextCheck = 'document',
}) => {
  'required': required,
  'verified': verified,
  'provider': 'mock',
  'tier': tier,
  'method': 'nin',
  'last4': '1234',
  'verifiedAt': null,
  'requiredTier': requiredTier,
  'nextCheck': nextCheck,
  'checks': {
    'identity': 'passed',
    'bank_match': 'passed',
    'document': nextCheck == 'document' ? 'not_started' : 'passed',
    'selfie': 'not_started',
    'liveness': 'not_started',
    'aml_individual': 'passed',
  },
  'limits': {
    'documentKobo': 10000000,
    'biometricKobo': 100000000,
    'livenessRequired': false,
  },
};

void main() {
  test('parses progressive status and next check', () {
    final status = KycStatus.fromJson(statusJson());
    expect(status.tier, 1);
    expect(status.requiredTier, 2);
    expect(status.nextCheck, KycCheckKind.document);
    expect(status.checks[KycCheckKind.identity], KycCheckState.passed);
    expect(status.needsCheck, isTrue);
    expect(status.canWithdraw, isFalse);
  });

  test('verified tier is required for withdrawal', () {
    expect(KycStatus.fromJson(statusJson(verified: true)).canWithdraw, isFalse);
    expect(
      KycStatus.fromJson(statusJson(verified: true, tier: 2, nextCheck: 'none'))
          .canWithdraw,
      isTrue,
    );
    expect(
      KycStatus.fromJson(statusJson(required: false, nextCheck: 'none'))
          .needsCheck,
      isFalse,
    );
  });

  test('unknown status enums fail closed', () {
    for (final change in [
      {'nextCheck': 'surprise'},
      {'provider': 'surprise'},
      {'method': 'surprise'},
      {
        'checks': {'surprise': 'passed'},
      },
      {
        'checks': {'identity': 'surprise'},
      },
    ]) {
      expect(
        () => KycStatus.fromJson({...statusJson(), ...change}),
        throwsFormatException,
      );
    }
  });

  test('withdrawal requires every check for the required tier', () {
    final checks = {
      'identity': 'passed',
      'bank_match': 'passed',
      'aml_individual': 'passed',
      'document': 'passed',
    };
    final ready = {
      ...statusJson(verified: true, tier: 2, nextCheck: 'none'),
      'checks': checks,
    };
    expect(KycStatus.fromJson(ready).canWithdraw, isTrue);
    for (final check in [
      'identity',
      'bank_match',
      'aml_individual',
      'document',
    ]) {
      for (final value in ['pending', 'failed', 'review', 'not_started']) {
        expect(
          KycStatus.fromJson({
            ...ready,
            'checks': {...checks, check: value},
          }).canWithdraw,
          isFalse,
          reason: '$check must be passed, not $value',
        );
      }
    }
    expect(
      KycStatus.fromJson({...ready, 'nextCheck': 'document'}).canWithdraw,
      isFalse,
    );
  });

  test('provider outage is not treated as verified', () async {
    final api = FakeApi()..offline = true;
    final service = KycService(api.api());
    await expectLater(service.status(), throwsA(isA<KycRefused>()));
  });

  test('configuration and review refusals never advance', () async {
    for (final code in ['KYC_NOT_CONFIGURED', 'KYC_REVIEW', 'KYC_FAILED']) {
      final api = FakeApi();
      api.on('GET', '/me/kyc', (_) => refused(503, code));
      await expectLater(
        KycService(api.api()).status(),
        throwsA(
          isA<KycRefused>().having(
            (e) => e.problem,
            'problem',
            code == 'KYC_REVIEW'
                ? KycProblem.review
                : code == 'KYC_FAILED'
                ? KycProblem.failed
                : KycProblem.unavailable,
          ),
        ),
      );
    }
  });

  test('identity and evidence writes carry unique idempotency keys', () async {
    final api = FakeApi();
    api.data('POST', '/me/kyc', statusJson(nextCheck: 'document'));
    api.data('POST', '/me/kyc/document', statusJson(nextCheck: 'selfie'));
    api.data('POST', '/me/kyc/selfie', statusJson(tier: 2, nextCheck: 'none'));
    final service = KycService(api.api());
    await service.verify(
      const KycCheck(
        method: KycMethod.nin,
        number: '12345678901',
        firstName: 'Ada',
        lastName: 'Obi',
      ),
    );
    await service.upload(
      KycCheckKind.document,
      const KycEvidence(
        filename: 'id.png',
        bytes: [1, 2, 3],
        contentType: 'image/png',
      ),
    );
    await service.upload(
      KycCheckKind.selfie,
      const KycEvidence(
        filename: 'selfie.jpg',
        bytes: [4, 5, 6],
        contentType: 'image/jpeg',
      ),
    );
    final keys = [
      for (final request in api.requests)
        if (request.method == 'POST') request.headers['idempotency-key'],
    ];
    expect(keys, hasLength(3));
    expect(
      keys,
      everyElement(isA<String>().having((s) => s, 'key', isNotEmpty)),
    );
    expect(keys.toSet(), hasLength(3));
  });

  test('retries reuse the key for the same logical attempt', () async {
    final api = FakeApi();
    api.data('POST', '/me/kyc', statusJson());
    api.data('POST', '/me/kyc/document', statusJson());
    var keys = 0;
    final service = KycService(api.api(), newKey: () => 'key-${++keys}');
    const check = KycCheck(
      method: KycMethod.nin,
      number: '12345678901',
      firstName: 'Ada',
      lastName: 'Obi',
    );
    const file = KycEvidence(
      filename: 'id.png',
      bytes: [1],
      contentType: 'image/png',
    );
    await service.verify(check);
    await service.verify(check);
    await service.upload(KycCheckKind.document, file);
    await service.upload(KycCheckKind.document, file);
    expect(api.to('/me/kyc').map((r) => r.headers['idempotency-key']), [
      'key-1',
      'key-1',
    ]);
    expect(
      api.to('/me/kyc/document').map((r) => r.headers['idempotency-key']),
      ['key-2', 'key-2'],
    );
    expect(keys, 2);
  });

  test(
    'uploads enforce size and check-specific file types before sending',
    () async {
      final api = FakeApi();
      final service = KycService(api.api());
      final oversized = KycEvidence(
        filename: 'id.png',
        bytes: List.filled(10 * 1024 * 1024 + 1, 0),
        contentType: 'image/png',
      );
      await expectLater(
        service.upload(KycCheckKind.document, oversized),
        throwsA(
          isA<KycRefused>().having(
            (e) => e.problem,
            'problem',
            KycProblem.invalid,
          ),
        ),
      );
      for (final check in [KycCheckKind.selfie, KycCheckKind.liveness]) {
        await expectLater(
          service.upload(
            check,
            const KycEvidence(
              filename: 'id.pdf',
              bytes: [1],
              contentType: 'application/pdf',
            ),
          ),
          throwsA(isA<KycRefused>()),
        );
      }
      expect(api.requests, isEmpty);
    },
  );
}
