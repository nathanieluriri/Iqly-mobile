import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/router.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'submit_harness.dart';

Future<void> _golden(
  WidgetTester tester,
  String name,
  Map<String, Object> prefs, {
  String briefId = 'c5',
  IqlyRepository? repository,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  await pumpApp(
    tester,
    Routes.submitTo(briefId),
    prefs: prefs,
    repository: repository,
    overrides: instantSubmit(),
  );
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/$name.png');
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('answer too short (34:24)', (tester) async {
    await _golden(
      tester,
      'submit_answer_too_short',
      submitDraftPrefs(title: SubmitCopy.title, answer: SubmitCopy.shortAnswer),
    );
  });

  testWidgets('answer ready (34:121)', (tester) async {
    await _golden(
      tester,
      'submit_answer_ready',
      submitDraftPrefs(title: SubmitCopy.title, answer: SubmitCopy.answer),
    );
  });

  testWidgets('quick questions (34:186)', (tester) async {
    await _golden(
      tester,
      'submit_quick_questions',
      submitDraftPrefs(
        title: SubmitCopy.title,
        answer: SubmitCopy.answer,
        answers: {
          'language': [SubmitCopy.language],
        },
      ),
      act: (tester) => _tap(tester, 'Continue'),
    );
  });

  testWidgets('sent (34:269)', (tester) async {
    await _golden(
      tester,
      'submit_sent',
      submitDraftPrefs(
        title: SubmitCopy.title,
        answer: SubmitCopy.answer,
        answers: {
          'language': [SubmitCopy.language],
          'placement': ['On the kiosk itself'],
        },
      ),
      act: (tester) async {
        await _tap(tester, 'Continue');
        await _tap(tester, 'Send response');
      },
    );
  });

  testWidgets('a brief with no questions: one step that sends', (tester) async {
    await _golden(
      tester,
      'submit_single_step',
      submitDraftPrefs(briefId: 'c9'),
      briefId: 'c9',
    );
  });

  testWidgets('a closed brief says why it cannot take a response', (
    tester,
  ) async {
    final repository = ScriptedRepository();
    repository.data.submissions.removeWhere((s) => s.briefId == 'c3');
    await _golden(
      tester,
      'submit_closed',
      signedInPrefs(),
      briefId: 'c3',
      repository: repository,
    );
  });
}
