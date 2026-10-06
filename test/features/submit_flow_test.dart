import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/responsive.dart';
import 'package:iqly_mobile/data/demo_data.dart';
import 'package:iqly_mobile/data/drafts_data.dart';
import 'package:iqly_mobile/data/repository.dart';
import 'package:iqly_mobile/data/submit_data.dart';
import 'package:iqly_mobile/data/submit_service.dart';
import 'package:iqly_mobile/features/discover/brief_detail_screen.dart';
import 'package:iqly_mobile/features/discover/home_screen.dart';
import 'package:iqly_mobile/features/submissions/my_submissions_screen.dart';
import 'package:iqly_mobile/features/submissions/submission_detail_screen.dart';
import 'package:iqly_mobile/features/submissions/submissions_routes.dart';
import 'package:iqly_mobile/features/submit/submit_screen.dart';
import 'package:iqly_mobile/features/submit/submit_state.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/confirm_sheet.dart';
import 'package:iqly_mobile/ui/field.dart';
import 'package:iqly_mobile/ui/poll_option.dart';
import 'package:iqly_mobile/ui/skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/submit_harness.dart';
import 'entry_harness.dart' show recordHaptics;

const _commit = 'HapticFeedbackType.lightImpact';
const _select = 'HapticFeedbackType.selectionClick';
const _success = 'HapticFeedbackType.successNotification';
const _error = 'HapticFeedbackType.mediumImpact';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _field(String label) =>
    find.byWidgetPredicate((w) => w is IqField && w.label == label);

Finder _answer() => find.descendant(
  of: find.byType(SubmitScreen),
  matching: find.byWidgetPredicate((w) => w is TextField && w.maxLines == null),
);

Finder _button(String label) =>
    find.byWidgetPredicate((w) => w is IqButton && w.label == label);

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  await tester.enterText(editable.evaluate().isEmpty ? field : editable, text);
  await tester.pumpAndSettle();
}

IqPollOptionState _option(WidgetTester tester, String label) => tester
    .widget<IqPollOption>(
      find.byWidgetPredicate((w) => w is IqPollOption && w.label == label),
    )
    .state;

List<Draft> _drafts(DemoRepository repository) => repository.data.drafts;

void main() {
  testWidgets(
    'B3: Brief detail to sent, then the entry is in My submissions as '
    'Under review',
    (tester) async {
      final haptics = recordHaptics(tester);
      late DemoSubmitService service;
      final picker = DemoAttachmentPicker();
      final repository = draftsRepository();
      await pumpApp(
        tester,
        Routes.brief('c5'),
        repository: repository,
        overrides: instantSubmit(picker: picker, created: (s) => service = s),
      );
      expect(find.byType(BriefDetailScreen), findsOneWidget);

      await _tap(tester, find.text('Start your submission'));
      expect(find.byType(SubmitScreen), findsOneWidget);
      expect(find.text('Your submission'), findsOneWidget);
      expect(find.text('Sunline'), findsOneWidget);
      expect(find.text('₦150k'), findsOneWidget);
      expect(find.text('Closes in 6h'), findsOneWidget);
      expect(find.text("What's your take?"), findsOneWidget);
      expect(find.text('20 more characters to go'), findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('0/5,000 characters'), findsOneWidget);
      expect(find.text('Drafts autosave until you send.'), findsOneWidget);
      expect(haptics, [_commit]);

      await _tap(tester, find.text('Continue'));
      expect(find.text("What's your take?"), findsOneWidget);
      expect(tester.widget<IqField>(_field('Title')).state, IqFieldState.error);
      expect(find.text('5 more characters'), findsOneWidget);
      expect(find.text('20 more characters'), findsOneWidget);
      expect(haptics, [_commit, _error]);

      await _type(tester, _field('Title'), SubmitCopy.title);
      await _type(tester, _answer(), SubmitCopy.shortAnswer);
      expect(find.text('4 more characters'), findsOneWidget);
      expect(find.text('16/5,000 characters'), findsOneWidget);
      expect(tester.widget<IqField>(_field('Title')).note, '25/120');
      expect(_drafts(repository).single.title, SubmitCopy.title);
      expect(_drafts(repository).single.step, DraftSteps.answer);

      await _type(tester, _answer(), SubmitCopy.answer);
      expect(find.text('Ready for the next step'), findsOneWidget);
      expect(find.text('74/5,000 characters'), findsOneWidget);

      await _tap(tester, find.text('Continue'));
      expect(find.text('A few quick questions'), findsOneWidget);
      expect(find.text('Which language should lead? (pick one)'), findsOne);
      expect(find.text('Question 1 needs an answer'), findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Up to 5 files · 10 MB each'), findsOneWidget);
      expect(tester.widget<IqButton>(_button('Submit')).disabled, isTrue);
      expect(_drafts(repository).single.step, DraftSteps.questions);

      await _tap(tester, find.bySemanticsLabel('Back'));
      expect(find.text("What's your take?"), findsOneWidget);
      expect(find.text('Ready for the next step'), findsOneWidget);
      await _tap(tester, find.text('Continue'));
      haptics.clear();

      await _tap(tester, find.text('Pidgin'));
      await _tap(tester, find.text(SubmitCopy.language));
      expect(_option(tester, SubmitCopy.language), IqPollOptionState.selected);
      expect(_option(tester, 'Pidgin'), IqPollOptionState.standard);
      expect(find.text('Question 2 needs an answer'), findsOneWidget);
      expect(haptics, [_select, _select]);

      await _type(
        tester,
        _field('Where would you put this line first?'),
        'On the kiosk itself',
      );
      expect(find.text('Ready to send'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.text('19/500 · required'), findsOneWidget);
      expect(tester.widget<IqButton>(_button('Submit')).disabled, isFalse);
      expect(_drafts(repository).single.step, DraftSteps.ready);

      await _tap(tester, find.text('Attachments'));
      expect(picker.picks, hasLength(1));
      expect(find.text('3 files · 4.1 MB'), findsOneWidget);
      expect(find.text('sunline-tagline.pdf'), findsOneWidget);
      expect(find.text('Added · 1.2 MB'), findsOneWidget);
      expect(find.text('Added · 0:42'), findsOneWidget);
      haptics.clear();

      await _tap(tester, find.text('Submit'));
      expect(find.text('Submitted. Good luck!'), findsOneWidget);
      expect(
        find.text("Winners are picked after the brief closes. We'll tell you."),
        findsOneWidget,
      );
      expect(
        find.text('29 people have submitted so far, including you.'),
        findsOneWidget,
      );
      expect(haptics, [_success]);
      final request = service.requests.single;
      expect(request.briefId, 'c5');
      expect(request.title, SubmitCopy.title);
      expect(request.answer, SubmitCopy.answer);
      expect(request.answers, {
        'language': [SubmitCopy.language],
        'placement': ['On the kiosk itself'],
      });
      expect(request.files, hasLength(3));
      expect(_drafts(repository), isEmpty);

      await _tap(tester, find.text('View submission'));
      expect(find.byType(SubmissionDetailScreen), findsOneWidget);
      expect(find.text(SubmitCopy.title), findsOneWidget);
      expect(find.text('Under review'), findsOneWidget);
      expect(find.textContaining('Sent just now'), findsOneWidget);

      await _tap(tester, find.bySemanticsLabel('Back'));
      expect(find.byType(MySubmissionsScreen), findsOneWidget);
      expect(find.text('Under review · 3'), findsOneWidget);
      expect(find.text(SubmitCopy.title), findsOneWidget);
    },
  );

  testWidgets('B3: View submission draws the new one from its first frame '
      'while My submissions takes its 1.2 s to load', (tester) async {
    final repository = readyToSend();
    await pumpApp(
      tester,
      Routes.submitTo('c5'),
      repository: DemoRepository(
        repository.data,
        latency: const DemoLatency(submissions: Duration(milliseconds: 1200)),
      ),
      overrides: instantSubmit(),
    );
    await _tap(tester, find.text('Submit'));

    await tester.tap(find.text('View submission'));
    for (var at = 0; at <= 1500; at += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(SubmissionDetailScreen).evaluate().isEmpty) continue;
      expect(
        find.descendant(
          of: find.byType(SubmissionDetailScreen),
          matching: find.text(SubmitCopy.title),
        ),
        findsOneWidget,
        reason: 'at $at ms',
      );
      expect(find.byType(IqSkeleton), findsNothing, reason: 'at $at ms');
    }
    expect(find.text('View the brief'), findsOneWidget);
    expect(find.text('Under review'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.text('Under review · 3'), findsOneWidget);
    expect(find.text(SubmitCopy.title), findsOneWidget);
  });

  testWidgets('B4: a cold open of a submission waits behind the skeleton', (
    tester,
  ) async {
    await pumpApp(
      tester,
      submissionPath('s1'),
      repository: DemoRepository(
        DemoData(now: figmaNow),
        latency: const DemoLatency(submissions: Duration(milliseconds: 1200)),
      ),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 290));
    expect(find.byType(IqSkeleton), findsNothing);
    expect(find.text('Fizzo: short, loud, easy to say'), findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byType(IqSkeleton), findsWidgets);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.byType(IqSkeleton), findsNothing);
    expect(find.text('Fizzo: short, loud, easy to say'), findsOneWidget);
  });

  testWidgets('B3: Back to Discover goes home', (tester) async {
    await pumpApp(
      tester,
      Routes.submitTo('c5'),
      repository: readyToSend(),
      overrides: instantSubmit(),
    );
    await _tap(tester, find.text('Submit'));
    expect(find.text('Submitted. Good luck!'), findsOneWidget);
    await _tap(tester, find.text('Back to Discover'));
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('B3: back on the sent moment returns to the opener', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.brief('c5'),
      repository: readyToSend(),
      overrides: instantSubmit(),
    );
    await _tap(tester, find.text('Start your submission'));
    expect(find.text('A few quick questions'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text("What's your take?"), findsOneWidget);
    await _tap(tester, find.text('Continue'));
    await _tap(tester, find.text('Submit'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SubmitScreen), findsNothing);
    expect(find.byType(BriefDetailScreen), findsOneWidget);
  });

  testWidgets('B3: a brief already answered opens that submission', (
    tester,
  ) async {
    await pumpApp(tester, Routes.brief('c1'), overrides: instantSubmit());
    await _tap(tester, find.text('View your submission'));
    expect(find.byType(SubmitScreen), findsNothing);
    expect(find.byType(SubmissionDetailScreen), findsOneWidget);
    expect(find.text('Fizzo: short, loud, easy to say'), findsOneWidget);

    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(BriefDetailScreen), findsOneWidget);
  });

  testWidgets('B3: a brief without questions sends from the answer', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    await pumpApp(tester, Routes.submitTo('c9'), overrides: instantSubmit());
    expect(find.text('Swapit'), findsOneWidget);
    expect(find.text('1 of 1'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    await _type(tester, _field('Title'), 'Show the IMEI check');
    await _type(
      tester,
      _answer(),
      'A free IMEI and theft check on every phone.',
    );
    expect(find.text('Ready to send'), findsOneWidget);
    await _tap(tester, find.text('Submit'));
    expect(find.text('Submitted. Good luck!'), findsOneWidget);
    expect(find.textContaining('submitted so far'), findsNothing);
    expect(haptics, [_success]);
  });

  testWidgets('B3: a short title says what is missing when it loses focus', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.submitTo('c5'),
      repository: draftsRepository(),
      overrides: instantSubmit(),
    );
    await _type(tester, _field('Title'), 'Hi');
    expect(tester.widget<IqField>(_field('Title')).state, isNull);
    await tester.tap(_answer());
    await tester.pumpAndSettle();
    expect(tester.widget<IqField>(_field('Title')).state, IqFieldState.error);
    expect(find.text('3 more characters'), findsOneWidget);
    await _type(tester, _field('Title'), 'Hi there');
    await tester.tap(_answer());
    await tester.pumpAndSettle();
    expect(tester.widget<IqField>(_field('Title')).state, IqFieldState.valid);
    expect(find.text('8/120'), findsOneWidget);
  });

  testWidgets('B17: the saved draft comes back with when it was saved', (
    tester,
  ) async {
    await pumpApp(tester, Routes.brief('c5'), overrides: instantSubmit());
    await _tap(tester, find.text('Start your submission'));
    expect(find.text(SubmitCopy.title), findsOneWidget);
    expect(find.text(SubmitCopy.shortAnswer), findsOneWidget);
    expect(find.text('4 more characters to go'), findsOneWidget);
    expect(
      find.text('Welcome back. Your draft is here, saved 1d ago.'),
      findsOneWidget,
    );
    expect(find.text('Drafts autosave until you send.'), findsNothing);
  });

  testWidgets('B17: a draft past the answer opens on the questions', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.submitTo('c5'),
      repository: withDraft(
        title: SubmitCopy.title,
        answer: SubmitCopy.answer,
        step: DraftSteps.questions,
      ),
      overrides: instantSubmit(),
    );
    expect(find.text('A few quick questions'), findsOneWidget);
    expect(find.text('Question 1 needs an answer'), findsOneWidget);
  });

  testWidgets('B3: leaving with words written asks first (481:21364)', (
    tester,
  ) async {
    final repository = withDraft(
      title: SubmitCopy.title,
      answer: SubmitCopy.answer,
    );
    await pumpApp(
      tester,
      Routes.brief('c5'),
      repository: repository,
      overrides: instantSubmit(),
    );
    await _tap(tester, find.text('Start your submission'));

    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.text('Leave without sending?'), findsOneWidget);
    expect(
      find.text(
        'Your draft stays saved on this phone. Come back any time before the '
        'brief closes.',
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('Keep writing'));
    expect(find.byType(IqConfirmSheet), findsNothing);
    expect(find.byType(SubmitScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave without sending?'), findsOneWidget);
    await _tap(tester, find.text('Discard draft'));
    expect(find.byType(SubmitScreen), findsNothing);
    expect(find.byType(BriefDetailScreen), findsOneWidget);
    expect(_drafts(repository), isEmpty);
  });

  testWidgets('B3: an empty draft leaves without asking', (tester) async {
    await pumpApp(
      tester,
      Routes.brief('c5'),
      repository: draftsRepository(),
      overrides: instantSubmit(),
    );
    await _tap(tester, find.text('Start your submission'));
    await _tap(tester, find.bySemanticsLabel('Back'));
    expect(find.byType(IqConfirmSheet), findsNothing);
    expect(find.byType(BriefDetailScreen), findsOneWidget);
  });

  testWidgets('B3: a send that fails says so and Try again sends (481:21472)', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    late DemoSubmitService service;
    final repository = readyToSend();
    await pumpApp(
      tester,
      Routes.submitTo('c5'),
      repository: repository,
      overrides: instantSubmit(created: (s) => service = s..offline = true),
    );
    haptics.clear();
    await _tap(tester, find.text('Submit'));
    const failed = 'Couldn’t send. Your draft is saved on this phone.';
    expect(find.text(failed), findsOneWidget);
    expect(find.text('A few quick questions'), findsOneWidget);
    expect(haptics, [_error]);
    expect(_drafts(repository), hasLength(1));

    service.offline = false;
    await _tap(tester, find.text('Try again'));
    expect(find.text('Submitted. Good luck!'), findsOneWidget);
    expect(service.requests, hasLength(1));
  });

  testWidgets('B3: attachments upload, fail, retry and stop at five of '
      '10 MB (481:21544)', (tester) async {
    final haptics = recordHaptics(tester);
    final picker = DemoAttachmentPicker();
    final uploader = ScriptedUploader(
      failing: {'kiosk-photo.jpg'},
      holding: {'sunline-tagline.pdf'},
    );
    await pumpApp(
      tester,
      Routes.submitTo('c5'),
      repository: readyToSend(),
      overrides: instantSubmit(picker: picker, uploader: uploader),
    );
    await _tap(tester, find.text('Attachments'));
    expect(find.text('Uploading · 60%'), findsOneWidget);
    expect(find.text('Failed · tap to retry'), findsOneWidget);
    expect(find.text('Added · 0:42'), findsOneWidget);
    expect(tester.widget<IqButton>(_button('Submit')).disabled, isTrue);

    uploader.failing.clear();
    await _tap(tester, find.text('kiosk-photo.jpg'));
    expect(find.text('Failed · tap to retry'), findsNothing);
    expect(find.text('Added · 2.4 MB'), findsOneWidget);
    haptics.clear();

    picker.next = const [
      AttachmentFile(name: 'kiosk.pdf', bytes: 12 * 1024 * 1024),
      AttachmentFile(name: 'one.jpg', bytes: 1024),
      AttachmentFile(name: 'two.jpg', bytes: 1024),
      AttachmentFile(name: 'three.jpg', bytes: 1024),
    ];
    await _tap(tester, find.text('Attachments'));
    expect(find.text('Max 5 files.'), findsOneWidget);
    expect(find.text('two.jpg'), findsOneWidget);
    expect(find.text('three.jpg'), findsNothing);
    expect(haptics, [_error]);
  });

  testWidgets('B3: the answer stops at 5,000 characters', (tester) async {
    await pumpApp(
      tester,
      Routes.submitTo('c5'),
      repository: draftsRepository(),
      overrides: instantSubmit(),
    );
    await _type(tester, _answer(), 'a' * (SubmitLimits.answerMax + 20));
    expect(find.text('5000/5,000 characters'), findsOneWidget);
  });

  // A field's text input is its one-line value box inside the larger area
  // IqField focuses on tap, so the steps with fields check labels only.
  for (final (name, fields, act)
      in <(String, bool, Future<void> Function(WidgetTester))>[
        (
          'the answer',
          true,
          (tester) => tester.binding.handlePopRoute().then((_) async {
            await tester.pumpAndSettle();
          }),
        ),
        ('the questions', true, (tester) async {}),
        (
          'the sent moment',
          false,
          (tester) => _tap(tester, find.text('Submit')),
        ),
      ]) {
    testWidgets('B3: $name: 44 pt targets, all labelled', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        Routes.submitTo('c5'),
        repository: readyToSend(),
        overrides: instantSubmit(),
      );
      await act(tester);
      if (!fields) {
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      }
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('B3: a brief that does not load offers Try again', (
    tester,
  ) async {
    final service = _FailingOpen();
    await pumpApp(
      tester,
      Routes.submitTo('c5'),
      overrides: [submitServiceProvider.overrideWithValue(service)],
    );
    expect(find.text('Couldn’t load. Check your connection.'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    service.fail = false;
    await _tap(tester, find.text('Try again'));
    expect(find.text("What's your take?"), findsOneWidget);
  });

  test('signing out forgets the autosaves of earlier builds', () async {
    SharedPreferences.setMockInitialValues({
      'submit.draft.c5': '{"title":"A"}',
      'submit.draft.c9': '{"answer":"B"}',
      'session.signedIn': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await forgetSubmitDrafts(prefs);
    expect(prefs.getKeys(), {'session.signedIn'});
  });

  testWidgets('B3: the steps make room for the keyboard, Continue above it', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.submitTo('c5'),
      repository: withDraft(title: SubmitCopy.title, answer: SubmitCopy.answer),
      overrides: instantSubmit(),
    );
    await tester.tap(_answer());
    await tester.pumpAndSettle();
    tester.view.padding = const FakeViewPadding(top: 54);
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pumpAndSettle();
    const keyboardTop = 844.0 - 336;
    expect(tester.getRect(find.text('Continue')).bottom, lessThan(keyboardTop));
    expect(tester.getRect(_answer()).top, lessThan(keyboardTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('B3: the sent moment holds still while the keyboard leaves', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Routes.submitTo('c9'),
      repository: withDraft(
        briefId: 'c9',
        title: 'Show the IMEI check',
        answer: 'A free IMEI and theft check on every phone.',
      ),
      overrides: instantSubmit(),
    );
    await _tap(tester, find.text('Submit'));
    final content = find.byType(CenteredContent).first;
    final height = tester.getSize(content).height;
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    expect(tester.getSize(content).height, height);
  });
}

/// Opening the brief fails until [fail] is cleared.
class _FailingOpen extends DemoSubmitService {
  _FailingOpen() : super(DemoData(now: figmaNow), clock: () => figmaNow);

  bool fail = true;

  @override
  Future<SubmitOpening> open(String briefId) {
    if (fail) return Future.error(Exception('offline'));
    return super.open(briefId);
  }
}
