import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/assessment_data.dart';
import 'package:iqly_mobile/data/assessment_service.dart';
import 'package:iqly_mobile/data/kyc_service.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/features/kyc/kyc_controller.dart';
import 'package:iqly_mobile/features/kyc/kyc_status.dart';
import 'package:iqly_mobile/features/submit/start_requirements_sheet.dart';

final _brief = Brief(
  id: 'brief-1',
  title: 'Tell us how you save',
  body: 'Share your best saving habit.',
  tier: Tier.standard,
  category: Category.other,
  rewardPoolKobo: 100000,
  status: BriefStatus.live,
  deadline: null,
  businessName: 'Test business',
  createdAt: DateTime(2026, 11, 27),
);

class _Assessment extends AssessmentAccessController {
  _Assessment(this.initial);

  final AssessmentAccessState initial;

  @override
  AssessmentAccessState build() => initial;
}

class _Kyc extends KycController {
  _Kyc(this.initial);

  final KycState initial;

  @override
  KycState build() => initial;
}

AssessmentAccessState _assessment({
  bool canTake = false,
  bool canResume = false,
  bool passed = false,
  String state = 'needed',
}) => AssessmentAccessState(
  access: AssessmentAccess(
    canTake: canTake,
    canResume: canResume,
    canAccessChallenges: passed,
    state: state,
  ),
);

KycState _kyc({int tier = 0, bool verified = false, bool loading = false}) =>
    KycState(
      status: KycStatus(
        tier: tier,
        verified: verified,
        nextCheck: tier > 0 ? KycCheckKind.none : KycCheckKind.identity,
      ),
      loading: loading,
    );

Future<void> _pump(
  WidgetTester tester, {
  required AssessmentAccessState assessment,
  required KycState kyc,
  VoidCallback? onReady,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        assessmentAccessProvider.overrideWith(() => _Assessment(assessment)),
        kycControllerProvider.overrideWith(() => _Kyc(kyc)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StartRequirementsSheet(brief: _brief, onReady: onReady),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('qualification is the first clear step', (tester) async {
    await _pump(
      tester,
      assessment: _assessment(canTake: true),
      kyc: const KycState(),
    );
    expect(find.text('Qualify to take on this brief'), findsOneWidget);
    expect(find.text('Proceed to qualification'), findsOneWidget);
    expect(find.text('Verify your identity to submit'), findsNothing);
  });

  testWidgets('a passed qualification shows the NIN verification step', (
    tester,
  ) async {
    await _pump(
      tester,
      assessment: _assessment(passed: true, state: 'passed'),
      kyc: _kyc(),
    );
    expect(find.text('Verify your identity to submit'), findsOneWidget);
    expect(find.text('Proceed to verification'), findsOneWidget);
    expect(find.text('Qualification test'), findsNothing);
  });

  testWidgets('checking has no forward CTA', (tester) async {
    await _pump(
      tester,
      assessment: const AssessmentAccessState(),
      kyc: const KycState(),
    );
    expect(find.text('Checking requirements'), findsOneWidget);
    expect(find.text('Proceed to qualification'), findsNothing);
    expect(find.text('Proceed to verification'), findsNothing);
  });

  testWidgets('ready completes the sheet once', (tester) async {
    var ready = 0;
    await _pump(
      tester,
      assessment: _assessment(passed: true, state: 'passed'),
      kyc: _kyc(tier: 1, verified: true),
      onReady: () => ready++,
    );
    await tester.pump();
    expect(ready, 1);
  });
}
