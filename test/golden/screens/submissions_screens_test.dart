import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'submissions_harness.dart';

Future<void> _golden(
  WidgetTester tester,
  String name,
  String location, [
  IqlyRepository? repository,
]) async {
  await pumpApp(tester, location, repository: repository);
  await expectMatchesGolden(
    find.byType(MaterialApp),
    'goldens/submissions_$name.png',
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('my submissions (35:24)', (tester) async {
    await _golden(tester, 'list', Routes.submissions);
  });

  testWidgets('submission detail (35:146)', (tester) async {
    await _golden(tester, 'detail', submissionPath('s4'));
  });

  testWidgets('loading (165:8524)', (tester) async {
    await _golden(
      tester,
      'loading',
      Routes.submissions,
      PendingSubmissionsRepository(),
    );
  });

  testWidgets('empty (165:8608)', (tester) async {
    await _golden(
      tester,
      'empty',
      Routes.submissions,
      EmptySubmissionsRepository(),
    );
  });

  testWidgets('failed to load (165:8700)', (tester) async {
    await _golden(
      tester,
      'failed',
      Routes.submissions,
      FailingSubmissionsRepository(),
    );
  });
}
