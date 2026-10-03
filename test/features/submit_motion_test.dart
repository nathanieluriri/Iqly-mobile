import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/features/submit/submit_thread.dart';
import 'package:iqly_mobile/features/submit/submit_widgets.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/highlight.dart';

import '../golden/screens/app_harness.dart';
import '../golden/screens/submit_harness.dart';
import 'entry_harness.dart' show recordHaptics;

const _short = ThreadLook.error('4 more characters', '1 of 2');
const _ready = ThreadLook.ready('Ready for the next step');
const _empty = ThreadLook.progress('20 more characters', '1 of 2');

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _thread(WidgetTester tester, ThreadLook look) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 358, child: SubmitThread(look: look)),
      ),
    ),
  ),
);

/// How far each brush of the rule shows (share of the width) and how
/// opaque it is, bottom to top.
List<(double, double)> _brushes(WidgetTester tester) {
  final clips = find.descendant(
    of: find.byType(SubmitThread),
    matching: find.byType(ClipRect),
  );
  return [
    for (final element in clips.evaluate())
      (
        (element.widget as ClipRect).clipper!
                .getClip(const Size(358, 6))
                .right /
            358,
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byWidget(element.widget),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
      ),
  ];
}

void main() {
  group('SubmitThread (MOTION-SPEC §5.26)', () {
    testWidgets('a short answer turning ready runs the rule half to full in '
        '240 ms while the colours cross over 160', (tester) async {
      await _thread(tester, _short);
      expect(_brushes(tester), [(1.0, 1.0)]);

      await _thread(tester, _ready);
      await tester.pump();
      var brushes = _brushes(tester);
      expect(brushes, hasLength(2));
      expect(brushes.last.$1, closeTo(0.5, 0.01));

      await tester.pump(const Duration(milliseconds: 80));
      brushes = _brushes(tester);
      expect(brushes.last.$1, inExclusiveRange(0.5, 1));
      expect(brushes.first.$2, inExclusiveRange(0, 1));
      expect(brushes.last.$2, inExclusiveRange(0, 1));

      await tester.pump(const Duration(milliseconds: 90));
      brushes = _brushes(tester);
      expect(brushes.first.$2, 0);
      expect(brushes.last.$2, 1);
      expect(brushes.last.$1, lessThan(1));

      await tester.pumpAndSettle();
      expect(_brushes(tester), [(1.0, 1.0)]);
      expect(find.text('Ready for the next step'), findsOneWidget);
    });

    testWidgets('ready going short runs back to half as it turns red', (
      tester,
    ) async {
      await _thread(tester, _ready);
      await tester.pumpAndSettle();
      await _thread(tester, _short);
      await tester.pump(const Duration(milliseconds: 120));
      final brushes = _brushes(tester);
      expect(brushes.first.$1, inExclusiveRange(0.5, 1));
      await tester.pumpAndSettle();
      expect(_brushes(tester), [(1.0, 1.0)]);
    });

    testWidgets('Ready on arrival draws the full rule left to right', (
      tester,
    ) async {
      await _thread(tester, _ready);
      expect(_brushes(tester).single.$1, 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(_brushes(tester).single.$1, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 120));
      expect(_brushes(tester).single.$1, 1);
    });

    testWidgets('the words roll from one count to the next', (tester) async {
      await _thread(tester, _short);
      await _thread(
        tester,
        const ThreadLook.error('3 more characters', '1 of 2'),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('3 more characters'), findsOneWidget);
    });

    testWidgets('reduced motion: the new state at once', (tester) async {
      _reduce(tester);
      await _thread(tester, _ready);
      expect(_brushes(tester), [(1.0, 1.0)]);
      await _thread(tester, _empty);
      await tester.pump();
      expect(_brushes(tester), [(1.0, 1.0)]);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

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
        prefs: submitDraftPrefs(
          title: SubmitCopy.title,
          answer: SubmitCopy.answer,
          answers: {
            'language': [SubmitCopy.language],
            'placement': ['On the kiosk itself'],
          },
        ),
        overrides: instantSubmit(),
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send response'));
      await tester.pump();
      await tester.pump();
    }

    double inkRise(WidgetTester tester) => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(BulbArrival),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .getTranslation()
        .y;

    testWidgets('the Bulb rises, its sweep wipes, the Highlight waits for '
        '+240 and the success haptic plays as it lands', (tester) async {
      final haptics = recordHaptics(tester);
      await send(tester);
      expect(find.byType(BulbArrival), findsOneWidget);
      expect(haptics.last, 'HapticFeedbackType.successNotification');
      expect(inkRise(tester), closeTo(IqTravel.riseHero, 0.5));
      expect(find.byType(IqHighlight), findsNothing);
      expect(find.text('1 of 29'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 160));
      expect(inkRise(tester), inExclusiveRange(0, IqTravel.riseHero));
      expect(find.byType(IqHighlight), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(IqHighlight), findsOneWidget);

      await tester.pumpAndSettle();
      expect(inkRise(tester), 0);
      expect(find.text('1 of 29'), findsOneWidget);
    });

    testWidgets('reduced motion: fades only, the Highlight is there', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await send(tester, reduced: true);
      expect(find.byType(IqHighlight), findsOneWidget);
      expect(inkRise(tester), 0);
      expect(haptics.last, 'HapticFeedbackType.successNotification');
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('the answer rule crosses from err to ok over 160 ms', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    Future<void> area(AnswerLook look) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnswerArea(
            controller: controller,
            focusNode: focus,
            look: look,
            length: 0,
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

    await area(AnswerLook.error);
    expect(rule(), IqColors.err);
    await area(AnswerLook.ready);
    await tester.pump(const Duration(milliseconds: 80));
    expect(rule(), isNot(IqColors.err));
    expect(rule(), isNot(IqColors.ok));
    await tester.pump(const Duration(milliseconds: 80));
    expect(rule(), IqColors.ok);
  });
}
