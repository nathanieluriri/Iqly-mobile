import '../../data/assessment_service.dart';
import '../kyc/kyc_controller.dart';

enum StartRequirement {
  checking,
  qualification,
  qualificationResume,
  qualificationUnavailable,
  kyc,
  kycUnavailable,
  ready,
}

/// One resolver for phone Start, tablet Start and direct submit entry. The
/// backend remains authoritative; this only chooses the next helpful screen.
StartRequirement resolveStartRequirements(
  AssessmentAccessState assessment,
  KycState kyc,
) {
  final access = assessment.effectiveAccess;
  if (access == null || !access.canAccessChallenges) {
    if (access == null) return StartRequirement.checking;
    if (access.canResume) return StartRequirement.qualificationResume;
    if (access.canTake) return StartRequirement.qualification;
    return StartRequirement.qualificationUnavailable;
  }

  final status = kyc.status;
  if (status == null) {
    return kyc.loading
        ? StartRequirement.checking
        : StartRequirement.kycUnavailable;
  }
  if (status.canSubmit) return StartRequirement.ready;
  return StartRequirement.kyc;
}
