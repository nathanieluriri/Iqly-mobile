import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';

import '../golden.dart';
import 'screen_golden.dart';
import 'submissions_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('my submissions (35:24)', (tester) async {
    await expectScreenGolden(
      tester,
      'submissions_list',
      const DockFrame(child: MySubmissionsScreen()),
    );
  });

  testWidgets('submission detail (35:146)', (tester) async {
    await expectScreenGolden(
      tester,
      'submissions_detail',
      const SubmissionDetailScreen(id: 's4'),
    );
  });

  testWidgets('loading (165:8524)', (tester) async {
    await expectScreenGolden(
      tester,
      'submissions_loading',
      const DockFrame(child: MySubmissionsScreen()),
      overrides: [
        repositoryProvider.overrideWithValue(PendingSubmissionsRepository()),
      ],
    );
  });

  testWidgets('empty (165:8608)', (tester) async {
    await expectScreenGolden(
      tester,
      'submissions_empty',
      const DockFrame(child: MySubmissionsScreen()),
      overrides: [
        repositoryProvider.overrideWithValue(EmptySubmissionsRepository()),
      ],
    );
  });

  testWidgets('failed to load (165:8700)', (tester) async {
    await expectScreenGolden(
      tester,
      'submissions_failed',
      const DockFrame(child: MySubmissionsScreen()),
      overrides: [
        repositoryProvider.overrideWithValue(FailingSubmissionsRepository()),
      ],
    );
  });
}
