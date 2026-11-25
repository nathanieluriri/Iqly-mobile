import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/drafts/drafts_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/empty_state.dart';
import 'package:iqly_mobile/ui/illustration.dart';

import '../golden/golden.dart';
import '../golden/screens/app_harness.dart';
import '../golden/screens/more_harness.dart';

class _OnlyStatusRepository extends DemoRepository {
  _OnlyStatusRepository(this.status) : super(DemoData(now: figmaNow));

  final SubmissionStatus status;

  @override
  Future<List<Submission>> submissions() async => data.submissions
      .where((submission) => submission.status == status)
      .toList();
}

class _NoDraftsRepository extends DemoRepository {
  _NoDraftsRepository() : super(DemoData(now: figmaNow));

  @override
  Future<List<Draft>> drafts() async => const [];
}

Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectShrug(WidgetTester tester, String title) {
  final empty = find.byType(IqEmptyState);
  expect(empty, findsOneWidget);
  final state = tester.widget<IqEmptyState>(empty);
  expect(state.figure, IqFigures.shrug);
  expect(state.title, title);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('empty Under review lens uses the shared confused figure', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.submissions,
      repository: _OnlyStatusRepository(SubmissionStatus.winner),
    );
    _expectShrug(tester, 'Nothing under review');
  });

  testWidgets('empty Winners lens uses the shared confused figure', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.submissions,
      repository: _OnlyStatusRepository(SubmissionStatus.pending),
    );
    await _tap(tester, 'Winners');
    _expectShrug(tester, 'No wins yet');
  });

  testWidgets('empty Rejected lens uses the shared confused figure', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.submissions,
      repository: _OnlyStatusRepository(SubmissionStatus.pending),
    );
    await _tap(tester, 'Rejected');
    _expectShrug(tester, 'Nothing rejected');
  });

  testWidgets('empty Drafts stays open with a browse action', (tester) async {
    await pumpApp(tester, Routes.drafts, repository: _NoDraftsRepository());
    expect(find.byType(DraftsScreen), findsOneWidget);
    expect(find.byType(MySubmissionsScreen), findsNothing);
    _expectShrug(tester, 'No drafts yet');
    expect(find.text('Browse briefs'), findsOneWidget);
  });

  testWidgets('Discover Saved empty uses the shared confused figure', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.savedBriefs,
      prefs: {...signedInPrefs(), 'discover.savedBriefs': '[]'},
    );
    _expectShrug(tester, 'Nothing saved yet');
  });

  testWidgets('More Saved empty uses the shared confused figure', (
    tester,
  ) async {
    await pumpMore(
      tester,
      Routes.moreSavedBriefs,
      prefs: {...signedInPrefs(), 'discover.savedBriefs': '[]'},
    );
    _expectShrug(tester, 'Nothing saved yet');
  });
}
