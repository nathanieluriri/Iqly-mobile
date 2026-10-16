import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/data/activations_service.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/field.dart';

import '../golden.dart';
import 'app_harness.dart';
import 'submit_harness.dart';

/// Rows B3 and B17 at 390 x 844, one golden per Figma frame, named after
/// it. Montages against the Figma renders live outside the repo.
Future<void> _golden(
  WidgetTester tester,
  String name, {
  String location = '/briefs/c5/submit',
  IqlyRepository? repository,
  Future<void> Function(WidgetTester tester)? act,
  List<String> failing = const [],
  List<String> holding = const [],
  bool offline = false,
}) async {
  await pumpApp(
    tester,
    location,
    repository: repository ?? draftsRepository(),
    overrides: [
      ...instantSubmit(
        uploader: ScriptedUploader(
          failing: {...failing},
          holding: {...holding},
        ),
        created: (service) => service.offline = offline,
      ),
      activationsServiceProvider.overrideWithValue(
        DemoActivationsService(clock: () => figmaNow, load: Duration.zero),
      ),
    ],
  );
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await precacheImages(tester);
  await expectMatchesGolden(find.byType(MaterialApp), 'goldens/$name.png');
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  await tester.enterText(editable.evaluate().isEmpty ? field : editable, text);
  await tester.pumpAndSettle();
}

Finder _field(String label) =>
    find.byWidgetPredicate((w) => w is IqField && w.label == label);

Finder _answer() =>
    find.byWidgetPredicate((w) => w is TextField && w.maxLines == null);

Future<void> _write(WidgetTester tester, String answer) async {
  await _type(tester, _field('Title'), SubmitCopy.title);
  await _type(tester, _answer(), answer);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('pick a brief (409:75)', (tester) async {
    await _golden(tester, 'pick_a_brief', location: Routes.pickBrief);
  });

  testWidgets('answer too short (34:24)', (tester) async {
    await _golden(
      tester,
      'submit_answer_too_short',
      act: (tester) async {
        await _write(tester, SubmitCopy.shortAnswer);
        await _tap(tester, 'Continue');
      },
    );
  });

  testWidgets('answer ready (34:121)', (tester) async {
    await _golden(
      tester,
      'submit_answer_ready',
      act: (tester) => _write(tester, SubmitCopy.answer),
    );
  });

  testWidgets('writing (313:13631)', (tester) async {
    await _golden(
      tester,
      'submit_writing',
      act: (tester) => _write(tester, SubmitCopy.shortAnswer),
    );
  });

  testWidgets('draft restored (313:13650)', (tester) async {
    await _golden(
      tester,
      'submit_draft_restored',
      repository: withDraft(
        title: SubmitCopy.title,
        answer: SubmitCopy.shortAnswer,
      ),
    );
  });

  testWidgets('brief sheet (547:24763)', (tester) async {
    await _golden(
      tester,
      'submit_brief_sheet',
      act: (tester) async {
        await _write(tester, SubmitCopy.answer);
        await _tap(tester, 'View the brief');
      },
    );
  });

  testWidgets('quick questions (34:186)', (tester) async {
    await _golden(
      tester,
      'submit_quick_questions',
      repository: withDraft(
        title: SubmitCopy.title,
        answer: SubmitCopy.answer,
        answers: {
          'language': [SubmitCopy.language],
        },
        step: DraftSteps.questions,
      ),
    );
  });

  testWidgets('quick questions answered (490:24270)', (tester) async {
    await _golden(
      tester,
      'submit_questions_answered',
      repository: readyToSend(),
    );
  });

  testWidgets('attachments (481:21544)', (tester) async {
    await _golden(
      tester,
      'submit_attachments',
      repository: withDraft(
        title: SubmitCopy.title,
        answer: SubmitCopy.answer,
        answers: {
          'language': [SubmitCopy.language],
        },
        step: DraftSteps.questions,
      ),
      holding: ['sunline-tagline.pdf'],
      failing: ['kiosk-photo.jpg'],
      act: (tester) => _tap(tester, 'Attachments'),
    );
  });

  testWidgets('send failed (481:21472)', (tester) async {
    await _golden(
      tester,
      'submit_send_failed',
      offline: true,
      act: (tester) async {
        await _write(tester, SubmitCopy.answer);
        await _tap(tester, 'Continue');
        await _tap(tester, SubmitCopy.language);
        await _type(
          tester,
          _field('Where would you put this line first?'),
          SubmitCopy.placement,
        );
        await _tap(tester, 'Submit');
        await tester.tap(find.bySemanticsLabel('Back'));
      },
    );
  });

  testWidgets('sent (34:269)', (tester) async {
    await _golden(
      tester,
      'submit_sent',
      repository: readyToSend(),
      act: (tester) => _tap(tester, 'Submit'),
    );
  });

  testWidgets('a brief with no questions: one step that sends', (tester) async {
    await _golden(
      tester,
      'submit_single_step',
      location: Routes.submitTo('c9'),
    );
  });

  testWidgets('a closed brief says why it cannot take a response', (
    tester,
  ) async {
    final repository = draftsRepository();
    repository.data.submissions.removeWhere((s) => s.briefId == 'c3');
    await _golden(
      tester,
      'submit_closed',
      location: Routes.submitTo('c3'),
      repository: repository,
    );
  });
}
