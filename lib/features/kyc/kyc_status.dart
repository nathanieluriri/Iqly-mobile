import '../../data/live/live_account.dart' show apiText;

enum KycMethod { nin, bvn }

enum KycProvider { mock, dojah }

enum KycCheckKind {
  identity,
  bankMatch,
  document,
  selfie,
  liveness,
  cac,
  affiliate,
  tin,
  amlIndividual,
  amlOrganization,
  ownership,
  authority,
  none;

  static KycCheckKind parse(Object? value) {
    if (value == null) return KycCheckKind.none;
    final name = switch (value) {
      'bank_match' => 'bankMatch',
      'aml_individual' => 'amlIndividual',
      'aml_organization' => 'amlOrganization',
      final String value => value,
      _ => throw FormatException('Unknown KYC check', value),
    };
    return KycCheckKind.values.firstWhere(
      (check) => check.name == name,
      orElse: () => throw FormatException('Unknown KYC check', name),
    );
  }
}

enum KycCheckState { notStarted, pending, passed, failed, review }

class KycLimits {
  const KycLimits({
    this.documentKobo = 0,
    this.biometricKobo = 0,
    this.livenessRequired = false,
  });

  factory KycLimits.fromJson(Map<String, dynamic> json) => KycLimits(
    documentKobo: _int(json['documentKobo']),
    biometricKobo: _int(json['biometricKobo']),
    livenessRequired: json['livenessRequired'] == true,
  );

  final int documentKobo;
  final int biometricKobo;
  final bool livenessRequired;
}

/// The contributor contract returned by `GET /me/kyc`.
class KycStatus {
  const KycStatus({
    this.required = true,
    this.verified = false,
    this.provider = KycProvider.mock,
    this.tier = 0,
    this.method,
    this.last4,
    this.verifiedAt,
    this.requiredTier = 1,
    this.nextCheck = KycCheckKind.identity,
    this.checks = const {},
    this.limits = const KycLimits(),
  });

  factory KycStatus.fromJson(Map<String, dynamic> json) {
    final rawChecks = json['checks'];
    final verified = json['verified'] == true;
    final tier = _tier(json['tier']);
    final requiredTier = _requiredTier(json['requiredTier']);
    return KycStatus(
      required: json['required'] == true,
      verified: verified,
      provider: _provider(json['provider']),
      tier: tier,
      method: _method(json['method']),
      last4: apiText(json['last4']),
      verifiedAt: apiText(json['verifiedAt']),
      requiredTier: requiredTier,
      nextCheck: KycCheckKind.parse(json['nextCheck']),
      checks: {
        if (rawChecks is Map)
          for (final entry in rawChecks.entries)
            KycCheckKind.parse(entry.key): _checkState(entry.value),
      },
      limits: json['limits'] is Map
          ? KycLimits.fromJson((json['limits'] as Map).cast<String, dynamic>())
          : const KycLimits(),
    );
  }

  final bool required;
  final bool verified;
  final KycProvider provider;
  final int tier;
  final KycMethod? method;
  final String? last4;
  final String? verifiedAt;
  final int requiredTier;
  final KycCheckKind nextCheck;
  final Map<KycCheckKind, KycCheckState> checks;
  final KycLimits limits;

  bool get needsCheck =>
      required && (!verified || nextCheck != KycCheckKind.none);

  /// New challenge submissions require effective C1, independent of any
  /// higher tier needed for a larger withdrawal.
  bool get canSubmit => verified && tier >= 1;

  /// Mobile contributor Tier 1 deliberately exposes NIN only.
  bool get ninOnly => requiredTier == 1;

  bool get canWithdraw {
    if (!verified || tier < requiredTier || nextCheck != KycCheckKind.none) {
      return false;
    }
    final required = [
      KycCheckKind.identity,
      KycCheckKind.bankMatch,
      KycCheckKind.amlIndividual,
      if (requiredTier >= 2) KycCheckKind.document,
      if (requiredTier >= 3) ...[
        KycCheckKind.selfie,
        if (limits.livenessRequired) KycCheckKind.liveness,
      ],
    ];
    return required.every((check) => checks[check] == KycCheckState.passed);
  }

  bool get inReview =>
      nextCheck == KycCheckKind.none &&
      checks.values.contains(KycCheckState.review);
}

int _int(Object? value) => value is int && value >= 0 ? value : 0;

int _tier(Object? value) =>
    value is int && value >= 0 && value <= 3 ? value : 0;

int _requiredTier(Object? value) =>
    value is int && value >= 1 && value <= 3 ? value : 1;

KycProvider _provider(Object? value) => switch (value) {
  null || 'mock' => KycProvider.mock,
  'dojah' => KycProvider.dojah,
  _ => throw FormatException('Unknown KYC provider', value),
};

KycMethod? _method(Object? value) => switch (value) {
  null => null,
  'nin' => KycMethod.nin,
  'bvn' => KycMethod.bvn,
  _ => throw FormatException('Unknown KYC method', value),
};

KycCheckState _checkState(Object? value) => switch (value) {
  'not_started' => KycCheckState.notStarted,
  'pending' => KycCheckState.pending,
  'passed' => KycCheckState.passed,
  'failed' => KycCheckState.failed,
  'review' => KycCheckState.review,
  _ => throw FormatException('Unknown KYC check state', value),
};
