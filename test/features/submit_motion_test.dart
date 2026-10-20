import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/features/submit/submit_field.dart';
import 'package:iqly_mobile/features/submit/submit_header.dart';
import 'package:iqly_mobile/features/submit/submit_sent.dart';
import 'package:iqly_mobile/features/submit/submit_steps.dart';
import 'package:iqly_mobile/features/submit/submit_widgets.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/poll_option.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/submit_harness.dart';
import 'entry_harness.dart' show recordHaptics;

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  group('StepSwitcher (MOTION-SPEC §4.1)', () {
    Widget step(String name) => SizedBox(
      key: ValueKey(name),
      width: 100,
      height: 40,
      child: Text(name),
    );

    double dx(WidgetTester tester, String name) => tester
        .widget<Transform>(
          find
              .ancestor(of: find.text(name), matching: find.byType(Transform))
              .first,
        )
        .transform
        .getTranslation()
        .x;

    Future<void> show(WidgetTester tester, String name, {bool back = false}) =>
        tester.pumpWidget(
          MaterialApp(
            home: StepSwitcher(back: back, child: step(name)),
          ),
        );

    testWidgets('forward: the next step comes in from 24 right, 300 ms', (
      tester,
    ) async {
      await show(tester, 'answer');
      await show(tester, 'questions');
      await tester.pump();
      expect(dx(tester, 'questions'), closeTo(IqTravel.screen, 0.01));
      expect(dx(tester, 'answer'), closeTo(0, 0.01));
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        dx(tester, 'questions'),
        closeTo(IqTravel.screen * (1 - IqCurves.easeOut.transform(.5)), 0.5),
      );
      expect(
        dx(tester, 'answer'),
        closeTo(-IqTravel.screen * IqCurves.easeIn.transform(.5), 0.5),
      );
      await tester.pumpAndSettle();
      expect(find.text('answer'), findsNothing);
      expect(dx(tester, 'questions'), 0);
    });

    testWidgets('back: mirrored, in from the left over 240', (tester) async {
      await show(tester, 'questions');
      await show(tester, 'answer', back: true);
      await tester.pump();
      expect(dx(tester, 'answer'), closeTo(-IqTravel.screen, 0.01));
      await tester.pump(const Duration(milliseconds: 120));
      expect(dx(tester, 'questions'), greaterThan(0));
      await tester.pump(const Duration(milliseconds: 121));
      await tester.pump();
      expect(find.text('questions'), findsNothing);
    });

    testWidgets('reduced motion: a 150 crossfade, nothing slides', (
      tester,
    ) async {
      _reduce(tester);
      await show(tester, 'answer');
      await show(tester, 'questions');
      expect(
        find.ancestor(
          of: find.text('questions'),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 151));
      await tester.pump();
      expect(find.text('answer'), findsNothing);
    });
  });

  group('The sent moment (MOTION-SPEC §7.4)', () {
    Future<void> send(WidgetTester tester, {bool reduced = false}) async {
      await pumpApp(
        tester,
        Routes.submitTo('c5'),
        reducedMotion: reduced,
        repository: readyToSend(),
        overrides: instantSubmit(),
      );
      await tester.tap(find.text('Submit'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the Sender arrives and the success haptic plays as it '
        'lands', (tester) async {
      final haptics = recordHaptics(tester);
      await send(tester);
      expect(find.byType(SentMoment), findsOneWidget);
      expect(haptics.last, 'HapticFeedbackType.successNotification');
      await tester.pumpAndSettle();
      expect(
        find.text('29 people have submitted so far, including you.'),
        findsOneWidget,
      );
    });

    testWidgets('the questions keep what was sent while they fade out', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Routes.submitTo('c5'),
        reducedMotion: false,
        repository: readyToSend(),
        overrides: instantSubmit(),
      );
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RoundIconButton && w.label == 'More',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attachments'));
      await tester.pumpAndSettle();
      const file = 'voice-note.m4a';
      expect(find.text(file), findsOneWidget);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RoundIconButton && w.label == 'Close',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit'));
      await tester.pump();
      var frames = 0;
      for (var at = 16; at <= 400; at += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        if (find.byType(QuestionsStep).evaluate().isEmpty) break;
        if (find.byType(SentMoment).evaluate().isEmpty) continue;
        frames++;
        final language = tester.widgetList<IqPollOption>(
          find.byWidgetPredicate(
            (w) => w is IqPollOption && w.label == SubmitCopy.language,
          ),
        );
        expect(
          language.map((o) => o.state),
          everyElement(IqPollOptionState.selected),
          reason: 'at $at ms',
        );
        expect(
          tester
              .widget<SubmitField>(
                find.byWidgetPredicate(
                  (w) =>
                      w is SubmitField &&
                      w.label == 'Where would you put this line first?',
                ),
              )
              .counter,
          '56/500',
          reason: 'at $at ms',
        );
      }
      expect(frames, greaterThan(10));
      expect(find.byType(QuestionsStep), findsNothing);
    });

    testWidgets('reduced motion: everything lands, nothing keeps running', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await send(tester, reduced: true);
      expect(haptics.last, 'HapticFeedbackType.successNotification');
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('a field\'s line crosses to err over 160 ms, only once it '
      'is told', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    Future<void> field({required bool error}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubmitField(
            label: 'Your answer',
            requirement: 'At least 20 characters',
            placeholder: 'Write your answer',
            counter: '0/5,000',
            controller: controller,
            focusNode: focus,
            error: error,
            many: true,
          ),
        ),
      ),
    );
    Color rule() =>
        (tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(AnimatedContainer),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color!;

    await field(error: false);
    expect(rule(), IqColors.line);
    await field(error: true);
    await tester.pump(const Duration(milliseconds: 80));
    expect(rule(), isNot(IqColors.line));
    expect(rule(), isNot(IqColors.err));
    await tester.pump(const Duration(milliseconds: 80));
    expect(rule(), IqColors.err);
  });
}
