import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/assessment_data.dart';
import 'package:iqly_mobile/data/assessment_service.dart';
import 'package:iqly_mobile/data/kyc_service.dart';
import 'package:iqly_mobile/features/kyc/kyc_controller.dart';
import 'package:iqly_mobile/features/submit/start_requirements.dart';

AssessmentAccessState _assessment({
  AssessmentAccess? access,
  bool terminalPassed = false,
}) => AssessmentAccessState(access: access, terminalPassed: terminalPassed);

AssessmentAccess _access({
  bool canTake = false,
  bool canResume = false,
  bool canAccessChallenges = false,
  String state = 'needed',
}) => AssessmentAccess(
  canTake: canTake,
  canResume: canResume,
  canAccessChallenges: canAccessChallenges,
  state: state,
);

KycState _kyc({KycStatus? status, bool loading = false, KycRefused? error}) =>
    KycState(status: status, loading: loading, error: error);

KycStatus _status({int tier = 0, bool verified = false}) => KycStatus(
  tier: tier,
  verified: verified,
  nextCheck: tier > 0 ? KycCheckKind.none : KycCheckKind.identity,
);

void main() {
  test('first check waits instead of opening submit', () {
    expect(
      resolveStartRequirements(_assessment(), const KycState()),
      StartRequirement.checking,
    );
  });

  test('a cached can-take state goes straight to qualification', () {
    expect(
      resolveStartRequirements(
        _assessment(access: _access(canTake: true)),
        const KycState(),
      ),
      StartRequirement.qualification,
    );
  });

  test('an active session offers resume', () {
    expect(
      resolveStartRequirements(
        _assessment(access: _access(canResume: true, state: 'in_progress')),
        const KycState(),
      ),
      StartRequirement.qualificationResume,
    );
  });

  test('a cooldown does not offer a misleading qualification CTA', () {
    expect(
      resolveStartRequirements(
        _assessment(access: _access(state: 'unavailable')),
        const KycState(),
      ),
      StartRequirement.qualificationUnavailable,
    );
  });

  test('a terminal pass checks KYC next', () {
    expect(
      resolveStartRequirements(
        _assessment(terminalPassed: true),
        _kyc(status: _status()),
      ),
      StartRequirement.kyc,
    );
  });

  test('KYC loading waits while qualification is already passed', () {
    expect(
      resolveStartRequirements(
        _assessment(
          access: _access(canAccessChallenges: true, state: 'passed'),
        ),
        const KycState(),
      ),
      StartRequirement.checking,
    );
  });

  test('a KYC error without status fails closed', () {
    expect(
      resolveStartRequirements(
        _assessment(
          access: _access(canAccessChallenges: true, state: 'passed'),
        ),
        _kyc(error: const KycRefused(KycProblem.unavailable)),
      ),
      StartRequirement.kycUnavailable,
    );
  });

  test('tier zero is sent to verification', () {
    expect(
      resolveStartRequirements(
        _assessment(
          access: _access(canAccessChallenges: true, state: 'passed'),
        ),
        _kyc(status: _status()),
      ),
      StartRequirement.kyc,
    );
  });

  test('tier one is ready to start', () {
    expect(
      resolveStartRequirements(
        _assessment(
          access: _access(canAccessChallenges: true, state: 'passed'),
        ),
        _kyc(status: _status(tier: 1, verified: true)),
      ),
      StartRequirement.ready,
    );
  });
}
