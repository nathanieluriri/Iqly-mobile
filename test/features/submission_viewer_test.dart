import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/router.dart';

import '../golden/golden.dart';
import '../golden/screens/app_harness.dart';

const _briefContext =
    'Customers wait too long at the counter. Show a practical fix the team can '
    'test this week.';
const _answer = '''
A clear plan
Line 1: Split quick transactions from account opening.
Line 2: Put a triage host at the door.
Line 3: Give waiting people a numbered ticket.
Line 4: Move complex cases to a second desk.
Line 5: Review the queue every hour.
Line 6: Publish the wait time on a small board.
Line 7: Ask three customers what still felt slow.
Line 8: Keep the fastest lane open through lunch.
Line 9: Train the relief teller on both queues.
Line 10: Test the change for one week before expanding it.
Line 11: Track completed visits, not just people served.
Line 12: Keep a paper fallback for network outages.
Line 13: Move forms to the waiting area.
Line 14: Call the next ticket from the desk.
Line 15: Give complex customers a return time.
Line 16: Review results with staff on Friday.
Line 17: Remove the step that adds no trust.
Line 18: Keep signs short and bilingual.
Line 19: Make the queue visible from the entrance.
Line 20: Finish with a one-page rollout checklist.
The complete answer ends here.''';

class _ViewerRepository extends DemoRepository {
  _ViewerRepository() : super(DemoData(now: figmaNow));

  @override
  Future<List<Brief>> briefs({BriefsLoad load = BriefsLoad.any}) async => [
    Brief(
      id: 'viewer-brief',
      title: 'One counter for quick jobs',
      body: _briefContext,
      tier: Tier.standard,
      category: Category.customerExperience,
      rewardPoolKobo: 10000000,
      status: BriefStatus.closed,
      deadline: figmaNow.subtract(const Duration(days: 1)),
      businessName: 'Kudi Box',
      createdAt: figmaNow.subtract(const Duration(days: 30)),
      cover: 'assets/samples/covers/kudi-box-1.jpg',
      logo: 'assets/samples/logos/kudi-box.svg',
    ),
  ];

  @override
  Future<List<Submission>> submissions() async => [
    Submission(
      id: 'viewer-submission',
      briefId: 'viewer-brief',
      title: 'A faster counter plan',
      body: _answer,
      status: SubmissionStatus.filteredOut,
      createdAt: figmaNow,
    ),
  ];
}

class _WinnerViewerRepository extends _ViewerRepository {
  @override
  Future<List<Submission>> submissions() async => [
    for (final submission in await super.submissions())
      Submission(
        id: submission.id,
        briefId: submission.briefId,
        title: submission.title,
        body: submission.body,
        status: SubmissionStatus.winner,
        createdAt: submission.createdAt,
        files: submission.files,
      ),
  ];

  @override
  Future<List<LedgerEntry>> ledger() async => [
    LedgerEntry(
      id: 'viewer-award',
      type: LedgerType.award,
      amountKobo: 50000000,
      createdAt: figmaNow,
      submissionId: 'viewer-submission',
    ),
  ];
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openViewer(WidgetTester tester) async {
  await _tap(tester, 'View your submission');
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'Rejected result opens the complete submission in a phone sheet',
    (tester) async {
      await pumpApp(
        tester,
        resultPath('viewer-submission'),
        repository: _ViewerRepository(),
      );
      expect(find.byType(ResultScreen), findsOneWidget);

      await _openViewer(tester);

      expect(find.byType(SubmissionDetailScreen), findsNothing);
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.text('Your submission'), findsOneWidget);
      expect(find.text('Posted by'), findsOneWidget);
      expect(find.text('Kudi Box'), findsOneWidget);
      expect(find.text('One counter for quick jobs'), findsOneWidget);
      expect(find.text('The brief'), findsOneWidget);
      expect(find.text(_briefContext), findsOneWidget);
      expect(find.text('A faster counter plan'), findsOneWidget);
      expect(find.text(_answer), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('View your submission'), findsOneWidget);
      expect(find.text(_answer), findsNothing);
    },
  );

  testWidgets('Winner result opens the complete submission in place', (
    tester,
  ) async {
    await pumpApp(
      tester,
      resultPath('viewer-submission'),
      repository: _WinnerViewerRepository(),
    );
    expect(find.text('View wallet'), findsOneWidget);

    await _tap(tester, 'View submission');

    expect(find.byType(SubmissionDetailScreen), findsNothing);
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text(_briefContext), findsOneWidget);
    expect(find.text(_answer), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('View submission'), findsOneWidget);
    expect(find.text(_answer), findsNothing);
  });

  testWidgets('Tablet result opens the complete submission in a dialog', (
    tester,
  ) async {
    await pumpApp(
      tester,
      resultPath('viewer-submission'),
      repository: _ViewerRepository(),
      size: const Size(1024, 768),
      tabletFrame: true,
    );

    await _openViewer(tester);

    expect(find.byType(SubmissionDetailScreen), findsNothing);
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Your submission'), findsOneWidget);
    expect(find.text(_briefContext), findsOneWidget);
    expect(find.text(_answer), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('View your submission'), findsOneWidget);
    expect(find.text(_answer), findsNothing);
  });
}
