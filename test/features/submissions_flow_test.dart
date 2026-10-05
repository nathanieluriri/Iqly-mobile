import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submit/pick_brief_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/router.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/submissions_harness.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('list to detail, the brief and back; results for decided rows', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester, Routes.submissions);
    expect(find.text('5 sent · 2 under review'), findsOneWidget);
    expect(find.text('SENT 30D AGO · ₦50,000.00 AWARDED'), findsOneWidget);

    await _tap(tester, find.text('Bring the shop to the hostel'));
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    expect(
      find.text('Results land here when Unibooks decides.'),
      findsOneWidget,
    );
    expect(find.text('In 20 days'), findsOneWidget);

    await _tap(tester, find.text('View the brief'));
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    expect(find.text('How should a campus bookshop sell online?'), findsOne);

    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(MySubmissionsScreen), findsOneWidget);

    await _tap(tester, find.text('Ekpe: a name riders own'));
    expect(find.text('Your result'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(MySubmissionsScreen), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('One counter for quick jobs'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await _tap(tester, find.text('One counter for quick jobs'));
    expect(find.text('Your result'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));

    await _tap(tester, find.bySemanticsLabel(RegExp('Notifications')));
    expect(find.text('Notifications'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('failed to load, Try again loads the list', (tester) async {
    final repository = FailingSubmissionsRepository();
    await pumpApp(tester, Routes.submissions, repository: repository);
    expect(find.text('Nothing to show yet'), findsOneWidget);

    repository.fail = false;
    await _tap(tester, find.text('Try again'));
    expect(find.text('Bring the shop to the hostel'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('empty state opens Pick a brief (409:75)', (tester) async {
    await pumpApp(
      tester,
      Routes.submissions,
      repository: EmptySubmissionsRepository(),
    );
    expect(find.text('0 sent'), findsOneWidget);
    await _tap(tester, find.text('Browse briefs'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(PickBriefScreen), findsOneWidget);
    expect(find.byType(MySubmissionsScreen), findsNothing);
  });
}
