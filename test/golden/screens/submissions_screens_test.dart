import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/models.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/features/submissions/submissions_state.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'submissions_harness.dart';

Future<void> _golden(
  WidgetTester tester,
  String name,
  String location, {
  IqlyRepository? repository,
  SubmissionsTab? tab,
}) async {
  final container = await pumpApp(tester, location, repository: repository);
  if (tab != null) container.read(submissionsTabProvider.notifier).select(tab);
  // A load still running shows its skeleton after LoadingGate's 300 ms.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  await precacheImages(tester);
  await expectMatchesGolden(
    find.byType(MaterialApp),
    'goldens/submissions_$name.png',
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('under review (35:24)', (tester) async {
    await _golden(tester, 'under_review', Routes.submissions);
  });

  testWidgets('winners (324:14478)', (tester) async {
    await _golden(
      tester,
      'winners',
      Routes.submissions,
      tab: SubmissionsTab.winners,
    );
  });

  testWidgets('not selected (324:14520)', (tester) async {
    await _golden(
      tester,
      'not_selected',
      Routes.submissions,
      tab: SubmissionsTab.notSelected,
    );
  });

  testWidgets('submission detail (35:146)', (tester) async {
    await _golden(tester, 'detail', submissionPath('s4'));
  });

  testWidgets('submission detail, not selected (1639:125902)', (tester) async {
    await _golden(tester, 'detail_not_selected', submissionPath('s5'));
  });

  testWidgets('submission detail with the files sent (no frame)', (
    tester,
  ) async {
    await _golden(
      tester,
      'detail_files',
      submissionPath('s4'),
      repository: _WithFiles(),
    );
  });

  testWidgets('loading (165:8524)', (tester) async {
    await _golden(
      tester,
      'loading',
      Routes.submissions,
      repository: PendingSubmissionsRepository(),
    );
  });

  testWidgets('empty (165:8608)', (tester) async {
    await _golden(
      tester,
      'empty',
      Routes.submissions,
      repository: EmptySubmissionsRepository(),
    );
  });

  testWidgets('failed to load (165:8700)', (tester) async {
    await _golden(
      tester,
      'failed',
      Routes.submissions,
      repository: FailingSubmissionsRepository(),
    );
  });
}

/// The sample entries, s4 with a picture and a PDF sent with it.
class _WithFiles extends DemoRepository {
  _WithFiles() : super(DemoData(now: figmaNow));

  @override
  Future<List<Submission>> submissions() async => [
    for (final s in await super.submissions())
      s.id != 's4'
          ? s
          : Submission(
              id: s.id,
              briefId: s.briefId,
              title: s.title,
              body: s.body,
              status: s.status,
              createdAt: s.createdAt,
              brief: s.brief,
              award: s.award,
              note: s.note,
              files: const [
                SubmissionFile(id: 'f_1', type: 'image', url: '/f_1'),
                SubmissionFile(id: 'f_2', type: 'pdf', url: '/f_2'),
              ],
            ),
  ];
}
