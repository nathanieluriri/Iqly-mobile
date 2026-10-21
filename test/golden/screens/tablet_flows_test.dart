import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'discover_harness.dart';
import 'polls_notifications_help_harness.dart';
import 'submit_harness.dart';
import 'tablet_harness.dart';

const _frames = [TabletFrameSize.portrait, TabletFrameSize.landscape];

void main() {
  setUpAll(loadAppFonts);

  for (final frame in _frames) {
    final f = frame.name;

    testWidgets('T6 submit step 1, $f', (tester) async {
      await pumpTablet(
        tester,
        Routes.submitTo('c5'),
        frame: frame,
        repository: draftsRepository(),
        overrides: instantSubmit(uploader: ScriptedUploader()),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await expectTabletGolden(tester, 'submit_answer_$f');
    });

    testWidgets('T6 submit step 2, $f', (tester) async {
      await pumpTablet(
        tester,
        Routes.submitTo('c5'),
        frame: frame,
        repository: readyToSend(),
        overrides: instantSubmit(uploader: ScriptedUploader()),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await expectTabletGolden(tester, 'submit_questions_$f');
    });

    testWidgets('T7 my submissions, $f', (tester) async {
      await pumpTablet(tester, Routes.submissions, frame: frame);
      await expectTabletGolden(tester, 'submissions_$f');
    });

    testWidgets('T7 a submission opened, $f', (tester) async {
      await pumpTablet(tester, Routes.submissions, frame: frame);
      await tester.tap(find.text('Not selected').last);
      await tester.pumpAndSettle();
      await expectTabletGolden(tester, 'submissions_open_$f');
    });

    testWidgets('T9 quick polls, $f', (tester) async {
      await pumpTablet(
        tester,
        Routes.polls,
        frame: frame,
        overrides: pollsLane(),
      );
      await expectTabletGolden(tester, 'polls_$f');
    });

    testWidgets('T9 a poll opened, $f', (tester) async {
      await pumpTablet(
        tester,
        Routes.polls,
        frame: frame,
        overrides: pollsLane(),
      );
      await tester.tap(find.text('Answer').first);
      await tester.pumpAndSettle();
      await expectTabletGolden(tester, 'poll_dialog_$f');
    });

    testWidgets('T10 activations, $f', (tester) async {
      await pumpTablet(
        tester,
        Routes.activations,
        frame: frame,
        overrides: discoverOverrides(),
      );
      await expectTabletGolden(tester, 'activations_$f');
    });
  }
}
