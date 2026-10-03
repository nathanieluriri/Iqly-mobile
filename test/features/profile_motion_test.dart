import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iqly_mobile/features/profile/profile_motion.dart' as motion;
import 'package:iqly_mobile/features/profile/profile_screen.dart';
import 'package:iqly_mobile/features/profile/your_details_screen.dart';
import 'package:iqly_mobile/router.dart';
import 'package:iqly_mobile/ui/dock.dart';

import '../golden/screens/profile_harness.dart';
import 'entry_harness.dart';

const _ms = Duration(milliseconds: 1);

void _reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Finder _cue(Key key) =>
    find.ancestor(of: find.byKey(key), matching: find.byType(motion.Cue));

double _opacity(WidgetTester tester, Key key) {
  final fades = find.descendant(
    of: _cue(key),
    matching: find.byType(FadeTransition),
  );
  if (fades.evaluate().isEmpty) return 1;
  return tester.widget<FadeTransition>(fades.first).opacity.value;
}

double _rise(WidgetTester tester, Key key) {
  final moves = find.descendant(
    of: _cue(key),
    matching: find.byType(Transform),
  );
  if (moves.evaluate().isEmpty) return 0;
  return tester.widget<Transform>(moves.first).transform.getTranslation().y;
}

Widget _list(List<motion.Cue Function(Widget child)> cues, Duration length) =>
    MaterialApp(
      home: motion.Entrance(
        length: length,
        child: Column(
          children: [
            for (final (i, cue) in cues.indexed)
              cue(SizedBox(key: ValueKey(i), height: 10)),
          ],
        ),
      ),
    );

const _a = ValueKey(0);
const _b = ValueKey(1);

void main() {
  group('Entrance and Cue', () {
    testWidgets('arrive fades and rises 12, 260 EO, 40 ms apart', (
      tester,
    ) async {
      await tester.pumpWidget(
        _list([
          for (var i = 0; i < 2; i++)
            (child) => motion.Cue.arrive(i, child: child),
        ], motion.Entrance.listLength(2)),
      );
      expect(_opacity(tester, _a), 0);
      expect(_rise(tester, _a), 12);

      await tester.pump(_ms * 130);
      final a = _opacity(tester, _a);
      expect(a, inExclusiveRange(0, 1));
      expect(_opacity(tester, _b), lessThan(a));
      expect(
        _rise(tester, _a),
        closeTo(12 * (1 - motion.easeOut.transform(.5)), .5),
      );

      await tester.pump(_ms * 150);
      expect(_opacity(tester, _a), 1);
      expect(_rise(tester, _a), 0);
      expect(_opacity(tester, _b), lessThan(1));
      await tester.pump(_ms * 20);
      expect(_opacity(tester, _b), 1);
      await tester.pump(_ms);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('settle rises 8 and never fades', (tester) async {
      await tester.pumpWidget(
        _list([
          (child) => motion.Cue.settle(0, child: child),
        ], motion.Entrance.listLength(1)),
      );
      expect(_opacity(tester, _a), 1);
      expect(_rise(tester, _a), 8);
      await tester.pumpAndSettle();
      expect(_rise(tester, _a), 0);
    });

    testWidgets('slots past the sixth render in place', (tester) async {
      await tester.pumpWidget(
        _list([
          for (var i = 0; i < 7; i++)
            (child) => motion.Cue.arrive(i, child: child),
        ], motion.Entrance.listLength(7)),
      );
      expect(_opacity(tester, _a), 0);
      expect(_opacity(tester, const ValueKey(6)), 1);
      expect(_rise(tester, const ValueKey(6)), 0);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: arrive only fades, together, over 150; '
        'settle shows in place', (tester) async {
      _reduceMotion(tester);
      await tester.pumpWidget(
        _list([
          (child) => motion.Cue.arrive(0, child: child),
          (child) => motion.Cue.arrive(1, child: child),
          (child) => motion.Cue.settle(2, child: child),
        ], motion.Entrance.listLength(3)),
      );
      expect(_rise(tester, _a), 0);
      expect(_opacity(tester, const ValueKey(2)), 1);
      await tester.pump(_ms * 75);
      expect(_opacity(tester, _a), closeTo(.5, .01));
      expect(_opacity(tester, _b), _opacity(tester, _a));
      await tester.pump(_ms * 75);
      expect(_opacity(tester, _a), 1);
      await tester.pump(_ms);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Stamp', () {
    double scale(WidgetTester tester) => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(motion.Stamp),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    Widget stamp(int trigger, {double from = motion.restampFrom}) =>
        MaterialApp(
          home: Center(
            child: motion.Stamp(
              trigger: trigger,
              from: from,
              child: const SizedBox.square(dimension: 18),
            ),
          ),
        );

    testWidgets('re-stamps 1.15 to 1 over 160 on each new trigger', (
      tester,
    ) async {
      await tester.pumpWidget(stamp(0));
      expect(scale(tester), 1);
      await tester.pumpWidget(stamp(1));
      await tester.pump();
      expect(scale(tester), closeTo(1.15, .001));
      await tester.pump(_ms * 80);
      expect(scale(tester), inExclusiveRange(1, 1.15));
      await tester.pump(_ms * 80);
      expect(scale(tester), 1);
    });

    testWidgets('a pop from .6 overshoots a little and lands in 200', (
      tester,
    ) async {
      await tester.pumpWidget(stamp(0, from: motion.popFrom));
      await tester.pumpWidget(stamp(1, from: motion.popFrom));
      await tester.pump();
      expect(scale(tester), closeTo(.6, .001));
      var peak = 0.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(_ms * 10);
        peak = scale(tester) > peak ? scale(tester) : peak;
      }
      expect(peak, greaterThan(1));
      expect(peak, lessThan(1.06));
      expect(scale(tester), 1);
    });

    testWidgets('lands at once under reduced motion', (tester) async {
      _reduceMotion(tester);
      await tester.pumpWidget(stamp(0));
      await tester.pumpWidget(stamp(1));
      await tester.pump();
      expect(scale(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('pushPage', () {
    const page = ValueKey('b');

    Future<GoRouter> pumpRouter(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const Text('a')),
          GoRoute(
            path: '/b',
            pageBuilder: (context, state) => motion.pushPage(
              context,
              state,
              Scaffold(
                key: page,
                body: BackButton(onPressed: () => context.pop()),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      return router;
    }

    double shift(WidgetTester tester) => tester
        .widget<Transform>(
          find
              .ancestor(of: find.byKey(page), matching: find.byType(Transform))
              .first,
        )
        .transform
        .getTranslation()
        .x;

    double fade(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byKey(page),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    testWidgets('comes in from +24 over 300 EO, fading over the first 60%', (
      tester,
    ) async {
      final router = await pumpRouter(tester);
      router.push('/b');
      await tester.pump();
      await tester.pump();
      expect(shift(tester), closeTo(24, .5));
      expect(fade(tester), closeTo(0, .01));
      await tester.pump(_ms * 150);
      expect(
        shift(tester),
        closeTo(24 * (1 - motion.easeOut.transform(.5)), .5),
      );
      expect(fade(tester), closeTo(motion.easeOut.transform(.5 / .6), .02));
      await tester.pump(_ms * 150);
      expect(shift(tester), 0);
      expect(fade(tester), 1);
    });

    testWidgets('back pops over 240, even mid-push', (tester) async {
      final router = await pumpRouter(tester);
      router.push('/b');
      await tester.pump();
      await tester.pump(_ms * 150);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(_ms * 240);
      await tester.pump();
      expect(find.byKey(page), findsNothing);
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('reduced motion: a 150 crossfade, no shift', (tester) async {
      _reduceMotion(tester);
      final router = await pumpRouter(tester);
      router.push('/b');
      await tester.pump();
      await tester.pump(_ms * 75);
      expect(
        find.ancestor(of: find.byKey(page), matching: find.byType(Transform)),
        findsNothing,
      );
      expect(fade(tester), closeTo(.5, .02));
      await tester.pump(_ms * 75);
      expect(fade(tester), 1);
    });
  });

  group('Profile', () {
    double rowOpacity(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('Your details'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    testWidgets('rows arrive on the first visit only', (tester) async {
      await pumpProfileApp(
        tester,
        Routes.profile,
        reducedMotion: false,
        settle: false,
      );
      await tester.pump();
      expect(rowOpacity(tester), lessThan(.2));
      await tester.pump(_ms * 460);
      expect(rowOpacity(tester), 1);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(IqDock),
          matching: find.text('Submissions'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(IqDock),
          matching: find.text('Profile'),
        ),
      );
      await tester.pump();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(rowOpacity(tester), 1);
    });

    testWidgets('a switch flip gives the select haptic', (tester) async {
      final haptics = recordHaptics(tester);
      await pumpProfileApp(tester, Routes.notificationPreferences);
      await tester.tap(find.text('Polls'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('Save changes commits, then succeeds and returns', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await pumpProfileApp(tester, Routes.yourDetails);
      await tester.tap(find.text('Save changes'));
      await tester.pump(_ms * 300);
      await tester.pumpAndSettle();
      expect(haptics, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.successNotification',
      ]);
      expect(find.byType(YourDetailsScreen), findsNothing);
    });

    testWidgets('Delete my account gives the destructive haptic', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await pumpProfileApp(tester, Routes.deleteAccount);
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(haptics, ['HapticFeedbackType.mediumImpact']);
    });
  });
}
