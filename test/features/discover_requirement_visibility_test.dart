import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/assessment_data.dart';
import 'package:iqly_mobile/data/assessment_service.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/submit/start_requirements_sheet.dart';
import 'package:iqly_mobile/features/submit/submit_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/brief_card.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/discover_harness.dart';

class _DeniedAssessment extends AssessmentAccessController {
  @override
  AssessmentAccessState build() => const AssessmentAccessState(
    access: AssessmentAccess(
      canTake: true,
      canResume: false,
      canAccessChallenges: false,
      state: 'needed',
    ),
  );
}

Finder _card(String title) => find.byWidgetPredicate(
  (widget) => widget is IqBriefCard && widget.title == title,
);

Future<void> _openBrief(WidgetTester tester, String title) async {
  await tester.scrollUntilVisible(
    find.text(title),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('phone Discover shows unstarted briefs before qualification', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.home,
      overrides: [
        ...discoverOverrides(),
        assessmentAccessProvider.overrideWith(_DeniedAssessment.new),
      ],
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      _card('A tagline for a solar kiosk network'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(_card('A tagline for a solar kiosk network'), findsOneWidget);
  });

  testWidgets('phone Start opens requirements instead of submit', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.home,
      overrides: [
        ...discoverOverrides(),
        assessmentAccessProvider.overrideWith(_DeniedAssessment.new),
      ],
    );
    await _openBrief(tester, 'A tagline for a solar kiosk network');
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    await tester.tap(find.text('Start your submission'));
    await tester.pumpAndSettle();
    expect(find.byType(StartRequirementsSheet), findsOneWidget);
    expect(find.text('Proceed to qualification'), findsOneWidget);
    expect(find.byType(SubmitScreen), findsNothing);
  });

  testWidgets('tablet Discover shows unstarted briefs before qualification', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.home,
      size: const Size(1112, 834),
      tabletFrame: true,
      overrides: [
        ...discoverOverrides(),
        assessmentAccessProvider.overrideWith(_DeniedAssessment.new),
      ],
    );
    expect(find.text('A tagline for a solar kiosk network'), findsOneWidget);
  });
}
