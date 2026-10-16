import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/outcomes/result_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submit/pick_brief_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/wallet/wallet_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/dock.dart';

import '../golden/golden.dart';
import '../golden/screens/app_harness.dart';
import '../golden/screens/submissions_harness.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Under review: a card opens its detail, the brief and back', (
    tester,
  ) async {
    await pumpApp(tester, Routes.submissions);
    expect(find.text('Under review'), findsOneWidget);
    expect(find.text('Winners'), findsOneWidget);
    expect(find.text('Not selected'), findsOneWidget);
    expect(find.text('Closes in 20 days'), findsOneWidget);
    expect(find.text('Sent 1 day ago'), findsOneWidget);
    expect(find.byType(IqDock), findsOneWidget);

    await _tap(tester, find.text('Bring the shop to the hostel'));
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    expect(find.byType(IqDock), findsNothing);
    expect(
      find.text(
        'Sent 1 day ago · For: How should a campus bookshop sell '
        'online?',
      ),
      findsOneWidget,
    );
    expect(find.text('₦100k'), findsOneWidget);
    expect(find.text('Results after the brief closes.'), findsOneWidget);

    await _tap(tester, find.text('View the brief'));
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
  });

  testWidgets('Winners: the total foots to the awards and a card opens its '
      'result', (tester) async {
    await pumpApp(tester, Routes.submissions);
    await _tap(tester, find.text('Winners'));
    expect(find.text('₦62,500.00 won from 2 briefs'), findsOneWidget);
    expect(find.text('Won ₦50k'), findsOneWidget);
    expect(find.text('Won ₦12.5k'), findsOneWidget);
    expect(find.text('13 days ago'), findsOneWidget);

    await _tap(tester, find.text('Ekpe: a name riders own'));
    expect(find.byType(ResultScreen), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(MySubmissionsScreen), findsOneWidget);
    expect(find.text('₦62,500.00 won from 2 briefs'), findsOneWidget);

    await _tap(tester, find.text('₦62,500.00 won from 2 briefs'));
    expect(find.byType(WalletScreen), findsOneWidget);
  });

  testWidgets('Not selected: the card opens its result, another brief its '
      'page', (tester) async {
    await pumpApp(tester, Routes.submissions);
    await _tap(tester, find.text('Not selected'));
    expect(find.text('Didn’t pass screening'), findsOneWidget);
    expect(find.text('Try another brief'), findsOneWidget);
    expect(find.text('Rename our youth current account'), findsOneWidget);
    expect(find.text('Packaging ideas for a cassava snack'), findsOneWidget);

    await _tap(tester, find.text('One counter for quick jobs'));
    expect(find.text('Not selected this time'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));

    await _tap(tester, find.text('Rename our youth current account'));
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.text('Try another brief'), findsOneWidget);
  });

  testWidgets('the lens stays put across a dock switch', (tester) async {
    await pumpApp(tester, Routes.submissions);
    await _tap(tester, find.text('Winners'));
    await _tap(
      tester,
      find.descendant(of: find.byType(IqDock), matching: find.text('Wallet')),
    );
    await _tap(
      tester,
      find.descendant(
        of: find.byType(IqDock),
        matching: find.text('Submissions'),
      ),
    );
    expect(find.text('₦62,500.00 won from 2 briefs'), findsOneWidget);
  });

  testWidgets('failed to load, Try again loads the list', (tester) async {
    final repository = FailingSubmissionsRepository();
    await pumpApp(tester, Routes.submissions, repository: repository);
    expect(find.text('Couldn\'t load your submissions'), findsOneWidget);

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
    expect(find.text('No submissions yet'), findsOneWidget);
    await _tap(tester, find.text('Browse briefs'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(PickBriefScreen), findsOneWidget);
    expect(find.byType(MySubmissionsScreen), findsNothing);
  });
}
