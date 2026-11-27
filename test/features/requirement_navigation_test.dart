import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/api_client.dart';
import 'package:iqly_mobile/data/assessment_data.dart';
import 'package:iqly_mobile/data/assessment_service.dart';
import 'package:iqly_mobile/data/kyc_service.dart';
import 'package:iqly_mobile/data/token_store.dart';
import 'package:iqly_mobile/features/assessments/assessment_screen.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/kyc/kyc_controller.dart';
import 'package:iqly_mobile/features/kyc/kyc_routes.dart';
import 'package:iqly_mobile/features/kyc/kyc_status.dart';
import 'package:iqly_mobile/features/submit/start_requirements_sheet.dart';
import 'package:iqly_mobile/features/submit/submit_screen.dart';
import 'package:iqly_mobile/router.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/discover_harness.dart';

class _Assessment extends AssessmentAccessController {
  _Assessment(this.initial);

  final AssessmentAccessState initial;

  @override
  AssessmentAccessState build() => initial;
}

class _PassedService extends AssessmentService {
  _PassedService() : super(ApiClient(tokens: MemoryTokenStore()));

  @override
  Future<AssessmentAccess> access() async => const AssessmentAccess(
    canTake: false,
    canResume: false,
    canAccessChallenges: true,
    state: 'passed',
  );
}

class _Kyc extends KycController {
  _Kyc(this.initial);

  final KycState initial;

  @override
  KycState build() => initial;
}

AssessmentAccessState _denied() => const AssessmentAccessState(
  access: AssessmentAccess(
    canTake: true,
    canResume: false,
    canAccessChallenges: false,
    state: 'needed',
  ),
);

AssessmentAccessState _passed() => const AssessmentAccessState(
  access: AssessmentAccess(
    canTake: false,
    canResume: false,
    canAccessChallenges: true,
    state: 'passed',
  ),
  terminalPassed: true,
);

KycState _kyc({int tier = 0, bool verified = false}) => KycState(
  status: KycStatus(
    tier: tier,
    verified: verified,
    nextCheck: tier > 0 ? KycCheckKind.none : KycCheckKind.identity,
  ),
);

void main() {
  testWidgets('qualification pass returns to the brief that opened it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.brief('c2'),
      overrides: [
        ...discoverOverrides(),
        assessmentAccessProvider.overrideWith(() => _Assessment(_denied())),
        assessmentServiceProvider.overrideWithValue(_PassedService()),
      ],
    );
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    await tester.tap(find.text('Start your submission'));
    await tester.pumpAndSettle();
    expect(find.byType(StartRequirementsSheet), findsOneWidget);
    await tester.tap(find.text('Proceed to qualification'));
    await tester.pumpAndSettle();
    expect(find.byType(AssessmentScreen), findsOneWidget);
    await tester.tap(find.text('See briefs'));
    await tester.pumpAndSettle();
    expect(find.byType(AssessmentScreen), findsNothing);
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('direct submit shows qualification instead of the form', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.submitTo('c2'),
      overrides: [
        ...discoverOverrides(),
        assessmentAccessProvider.overrideWith(() => _Assessment(_denied())),
      ],
    );
    expect(find.byType(SubmitScreen), findsOneWidget);
    expect(find.byType(StartRequirementsSheet), findsOneWidget);
    expect(find.text('Proceed to qualification'), findsOneWidget);
  });

  testWidgets('direct submit shows KYC after qualification', (tester) async {
    await pumpApp(
      tester,
      Routes.submitTo('c2'),
      overrides: [
        ...discoverOverrides(),
        assessmentAccessProvider.overrideWith(() => _Assessment(_passed())),
        kycControllerProvider.overrideWith(() => _Kyc(_kyc())),
      ],
    );
    expect(find.byType(StartRequirementsSheet), findsOneWidget);
    expect(find.text('Proceed to verification'), findsOneWidget);
  });

  testWidgets('the KYC route uses the pop-on-complete screen', (tester) async {
    await pumpApp(
      tester,
      Routes.kyc,
      overrides: [kycControllerProvider.overrideWith(() => _Kyc(_kyc()))],
    );
    expect(find.byType(KycScreen), findsOneWidget);
  });
}
