import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/countdown.dart';

const _box = SizedBox(width: 100, height: 20);

Future<void> _pump(WidgetTester tester, Widget child, {bool reduced = false}) {
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  return tester.pumpWidget(MaterialApp(home: Center(child: child)));
}

double _dx(WidgetTester tester) => tester
    .widget<Transform>(
      find.descendant(of: find.byType(Shake), matching: find.byType(Transform)),
    )
    .transform
    .getTranslation()
    .x;

void main() {
  group('Shake', () {
    testWidgets('moves 2 px three times over 240 ms on each new trigger', (
      tester,
    ) async {
      await _pump(tester, const Shake(trigger: 0, child: _box));
      expect(_dx(tester), 0);

      await _pump(tester, const Shake(trigger: 1, child: _box));
      final seen = <double>[];
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        seen.add(_dx(tester));
      }
      expect(seen.reduce((a, b) => a > b ? a : b), closeTo(2, 0.1));
      expect(seen.reduce((a, b) => a < b ? a : b), closeTo(-2, 0.1));
      await tester.pumpAndSettle();
      expect(_dx(tester), closeTo(0, 0.001));
    });

    testWidgets('holds still under reduced motion', (tester) async {
      await _pump(tester, const Shake(trigger: 0, child: _box), reduced: true);
      await _pump(tester, const Shake(trigger: 1, child: _box), reduced: true);
      await tester.pump(const Duration(milliseconds: 40));
      expect(_dx(tester), 0);
    });
  });

  group('Wipe', () {
    ClipRect clip(WidgetTester tester) => tester.widget<ClipRect>(
      find.descendant(of: find.byType(Wipe), matching: find.byType(ClipRect)),
    );

    testWidgets('clips left to right, then lets go', (tester) async {
      await _pump(tester, const Wipe(child: _box));
      expect(clip(tester).clipBehavior, Clip.hardEdge);
      final start = clip(tester).clipper!.getClip(const Size(100, 20));
      expect(start.width, 0);
      await tester.pump(const Duration(milliseconds: 120));
      final mid = clip(tester).clipper!.getClip(const Size(100, 20)).width;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(100));
      await tester.pumpAndSettle();
      expect(clip(tester).clipBehavior, Clip.none);
    });

    testWidgets('is already in under reduced motion', (tester) async {
      await _pump(tester, const Wipe(child: _box), reduced: true);
      await tester.pump();
      expect(clip(tester).clipBehavior, Clip.none);
    });
  });

  group('Reveal', () {
    Opacity fade(WidgetTester tester) => tester.widget<Opacity>(
      find.descendant(of: find.byType(Reveal), matching: find.byType(Opacity)),
    );

    testWidgets('fades in and rises 4 px over 160 ms', (tester) async {
      await _pump(tester, const Reveal(child: _box));
      expect(fade(tester).opacity, 0);
      expect(fade(tester).alwaysIncludeSemantics, isTrue);
      await tester.pump(const Duration(milliseconds: 80));
      expect(fade(tester).opacity, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 80));
      expect(fade(tester).opacity, 1);
    });

    testWidgets('just appears under reduced motion', (tester) async {
      await _pump(tester, const Reveal(child: _box), reduced: true);
      expect(fade(tester).opacity, 1);
    });
  });

  group('tokens', () {
    test('the curves are the Figma easings', () {
      for (final (curve, x1, y1, x2, y2) in [
        (IqCurves.easeOut, 0.0, 0.0, 0.58, 1.0),
        (IqCurves.easeIn, 0.42, 0.0, 1.0, 1.0),
        (IqCurves.easeInOut, 0.42, 0.0, 0.58, 1.0),
      ]) {
        final cubic = curve as Cubic;
        expect([cubic.a, cubic.b, cubic.c, cubic.d], [x1, y1, x2, y2]);
      }
      expect(IqCurves.stamp.transform(0.7), greaterThan(1));
    });

    test('exits run about three quarters of their entrance', () {
      expect(IqDurations.screenBack.inMilliseconds, 240);
      expect(IqDurations.screen.inMilliseconds, 300);
      expect(ErrorMotion.shake, IqDurations.mark);
      expect(ErrorMotion.reveal, IqDurations.tick);
    });

    testWidgets('motion() and pressMotion() follow reduced motion', (
      tester,
    ) async {
      late Duration full, cut, fade, down, up, rmDown, rmUp;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            full = motion(context, IqDurations.swap);
            down = pressMotion(context, true);
            up = pressMotion(context, false);
            return MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  cut = motion(context, IqDurations.swap);
                  fade = motion(context, IqDurations.swap, fade: true);
                  rmDown = pressMotion(context, true);
                  rmUp = pressMotion(context, false);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );
      expect(full, IqDurations.swap);
      expect(cut, Duration.zero);
      expect(fade, IqDurations.crossfade);
      expect((down, up), (IqDurations.press, IqDurations.release));
      expect((rmDown, rmUp), (IqDurations.press, Duration.zero));
    });
  });

  group('haptics', () {
    List<String> record(WidgetTester tester) {
      final played = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          played.add(call.arguments as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      return played;
    }

    testWidgets('each moment in its weight: light taps, medium commits, '
        'heavy holds and destructive starts', (tester) async {
      final played = record(tester);
      for (final haptic in IqHaptics.values) {
        await haptic.play();
        await tester.pump(Duration.zero);
      }
      expect(played, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.successNotification',
        'HapticFeedbackType.mediumImpact',
      ]);
    });

    testWidgets('a wheel tick also plays the system click', (tester) async {
      final calls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add('${call.method} ${call.arguments}');
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await IqHaptics.tick.play();
      expect(calls, [
        'SystemSound.play SystemSoundType.click',
        'HapticFeedback.vibrate HapticFeedbackType.selectionClick',
      ]);
    });

    testWidgets('a result that lands with its commit plays alone (spec 2.7)', (
      tester,
    ) async {
      final played = record(tester);
      IqHaptics.commit.play();
      errorHaptic();
      await tester.pump(Duration.zero);
      expect(played, ['HapticFeedbackType.mediumImpact']);

      IqHaptics.commit.play();
      await Future<void>.value();
      IqHaptics.success.play();
      await tester.pump(Duration.zero);
      expect(played, [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.successNotification',
      ]);
    });

    testWidgets('a tap gives way to a result in its frame too', (tester) async {
      final played = record(tester);
      IqHaptics.tap.play();
      IqHaptics.success.play();
      await tester.pump(Duration.zero);
      expect(played, ['HapticFeedbackType.successNotification']);

      IqHaptics.tap.play();
      await tester.pump(Duration.zero);
      expect(played, [
        'HapticFeedbackType.successNotification',
        'HapticFeedbackType.lightImpact',
      ]);
    });

    testWidgets('a result that comes later follows its commit', (tester) async {
      final played = record(tester);
      IqHaptics.commit.play();
      await tester.pump(Duration.zero);
      expect(played, ['HapticFeedbackType.mediumImpact']);
      IqHaptics.success.play();
      expect(played, [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.successNotification',
      ]);
    });

    testWidgets('errors use the error notification on iOS', (tester) async {
      final played = record(tester);
      await errorHaptic();
      expect(played, ['HapticFeedbackType.errorNotification']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('entrances', () {
    double opacityOf(WidgetTester tester, Type type) => tester
        .widget<FadeTransition>(
          find
              .descendant(
                of: find.byType(type),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    Matrix4 transformOf(WidgetTester tester, Type type) => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(type),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform;

    testWidgets('Appear fades in as it rises 8, 220 ms', (tester) async {
      await _pump(tester, const Appear(child: _box));
      expect(opacityOf(tester, Appear), 0);
      expect(transformOf(tester, Appear).getTranslation().y, 8);
      await tester.pump(const Duration(milliseconds: 110));
      expect(opacityOf(tester, Appear), closeTo(_eo(0.5), 0.01));
      expect(
        transformOf(tester, Appear).getTranslation().y,
        closeTo(8 * (1 - _eo(0.5)), 0.01),
      );
      await tester.pump(const Duration(milliseconds: 110));
      expect(opacityOf(tester, Appear), 1);
      expect(transformOf(tester, Appear).getTranslation().y, 0);
    });

    testWidgets('Appear waits for its delay', (tester) async {
      await _pump(
        tester,
        const Appear(delay: Duration(milliseconds: 100), child: _box),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacityOf(tester, Appear), 0);
      await tester.pump(const Duration(milliseconds: 110));
      expect(opacityOf(tester, Appear), closeTo(_eo(0.5), 0.01));
    });

    testWidgets('reduced motion: Appear only fades, 150 ms', (tester) async {
      await _pump(tester, const Appear(child: _box), reduced: true);
      await tester.pump(const Duration(milliseconds: 75));
      expect(opacityOf(tester, Appear), closeTo(_eo(0.5), 0.01));
      expect(transformOf(tester, Appear).getTranslation().y, 0);
      await tester.pump(const Duration(milliseconds: 76));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('Pop grows from .6 as it fades in', (tester) async {
      await _pump(tester, const Pop(child: _box));
      expect(transformOf(tester, Pop).entry(0, 0), closeTo(0.6, 0.001));
      await tester.pump(const Duration(milliseconds: 220));
      expect(transformOf(tester, Pop).entry(0, 0), 1);
      expect(opacityOf(tester, Pop), 1);
    });

    testWidgets('a vertical Wipe draws top to bottom', (tester) async {
      await _pump(
        tester,
        const Wipe(
          axis: Axis.vertical,
          duration: IqDurations.tick,
          child: _box,
        ),
      );
      ClipRect clip() => tester.widget<ClipRect>(
        find.descendant(of: find.byType(Wipe), matching: find.byType(ClipRect)),
      );
      expect(clip().clipper!.getClip(const Size(100, 20)).height, 0);
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        clip().clipper!.getClip(const Size(100, 20)).height,
        closeTo(20 * _eo(0.5), 0.01),
      );
      await tester.pump(const Duration(milliseconds: 81));
      expect(clip().clipBehavior, Clip.none);
    });
  });

  group('Stagger', () {
    Widget list({bool play = true, StaggerMove move = StaggerMove.arrive}) =>
        Stagger(
          play: play,
          move: move,
          child: Column(
            children: [
              for (var i = 0; i < 8; i++)
                StaggerItem(
                  index: i,
                  child: SizedBox(key: ValueKey(i), width: 100, height: 10),
                ),
            ],
          ),
        );

    double rise(WidgetTester tester, int i) =>
        tester.getTopLeft(find.byKey(ValueKey(i))).dy - i * 10;

    double fade(WidgetTester tester, int i) => tester
        .widgetList<FadeTransition>(
          find.ancestor(
            of: find.byKey(ValueKey(i), skipOffstage: false),
            matching: find.byType(FadeTransition, skipOffstage: false),
          ),
        )
        .fold(1.0, (o, w) => o * w.opacity.value);

    testWidgets('items arrive 40 ms apart; those after the sixth, on '
        'screen, arrive with it', (tester) async {
      await _pumpTop(tester, list());
      await tester.pump();
      expect(rise(tester, 0), closeTo(12, 0.01));
      expect(fade(tester, 0), 0);
      expect(rise(tester, 6), closeTo(12, 0.01));
      expect(fade(tester, 7), 0);
      await tester.pump(const Duration(milliseconds: 170));
      expect(fade(tester, 0), closeTo(_eo(170 / 260), 0.01));
      expect(fade(tester, 2), closeTo(_eo(90 / 260), 0.01));
      expect(rise(tester, 5), closeTo(12, 0.01));
      await tester.pump(const Duration(milliseconds: 160));
      expect(fade(tester, 5), closeTo(_eo(130 / 260), 0.01));
      for (final i in [6, 7]) {
        expect(fade(tester, i), fade(tester, 5));
        expect(rise(tester, i), rise(tester, 5));
      }
      await tester.pump(const Duration(milliseconds: 130));
      for (var i = 0; i < 8; i++) {
        expect(rise(tester, i), 0);
        expect(fade(tester, i), 1);
      }
    });

    testWidgets('items after the sixth below the fold render in place', (
      tester,
    ) async {
      await _pumpTop(
        tester,
        SizedBox(
          width: 100,
          height: 300,
          child: Stagger(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < 20; i++)
                  StaggerItem(
                    index: i,
                    child: SizedBox(key: ValueKey(i), height: 30),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      for (final i in [6, 9]) {
        expect(fade(tester, i), 0, reason: 'item $i is on screen');
      }
      expect(fade(tester, 10), 1);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey(10), skipOffstage: false))
            .dy,
        300,
      );
      await tester.pump(const Duration(milliseconds: 330));
      expect(fade(tester, 9), closeTo(_eo(130 / 260), 0.01));
      expect(fade(tester, 10), 1);
    });

    testWidgets('settle only rises 8, and a list not playing stands still', (
      tester,
    ) async {
      await _pumpTop(tester, list(move: StaggerMove.settle));
      expect(rise(tester, 0), closeTo(8, 0.01));
      expect(fade(tester, 0), 1);
      await _pumpTop(tester, list(play: false), key: 2);
      expect(rise(tester, 0), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: everything fades in together, 150', (
      tester,
    ) async {
      await _pumpTop(tester, list(), reduced: true);
      await tester.pump(const Duration(milliseconds: 75));
      expect(fade(tester, 0), closeTo(_eo(0.5), 0.01));
      expect(fade(tester, 5), closeTo(_eo(0.5), 0.01));
      expect(fade(tester, 7), closeTo(_eo(0.5), 0.01));
      expect(rise(tester, 5), 0);
    });
  });

  group('RollingText', () {
    Widget figure(String text, {bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: RollingText(text, style: IqText.figureSmall)),
      ),
    );

    testWidgets('only the changed digits roll, 160 ms', (tester) async {
      await tester.pumpWidget(figure('5h 40m'));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(figure('5h 39m'));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('5h 40m'), findsOneWidget);
      expect(find.text('5h 39m'), findsOneWidget);
      final leaving = tester.widget<Transform>(
        find
            .ancestor(of: find.text('5h 40m'), matching: find.byType(Transform))
            .first,
      );
      expect(
        leaving.transform.getTranslation().y,
        closeTo(-6 * _eo(0.5), 0.01),
      );
      await tester.pump(const Duration(milliseconds: 81));
      await tester.pump();
      expect(find.text('5h 40m'), findsNothing);
      expect(find.byType(RichText), findsOneWidget);
    });

    testWidgets('a change while it rolls does not start the roll over', (
      tester,
    ) async {
      await tester.pumpWidget(figure('17'));
      await tester.pumpWidget(figure('18'));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(figure('19'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('18'), findsNothing);
      final leaving = tester.widget<Transform>(
        find
            .ancestor(of: find.text('17'), matching: find.byType(Transform))
            .first,
      );
      expect(
        leaving.transform.getTranslation().y,
        closeTo(-6 * _eo(120 / 160), 0.01),
      );
      await tester.pump(const Duration(milliseconds: 41));
      await tester.pump();
      expect(find.text('17'), findsNothing);
      expect(find.text('19'), findsOneWidget);
      expect(find.byType(RichText), findsOneWidget);
    });

    testWidgets('a count that changes faster than it rolls rests, and rolls '
        'again once it has been still for a roll', (tester) async {
      await tester.pumpWidget(figure('1'));
      await tester.pumpWidget(figure('2'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(figure('3'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(figure('4'));
      expect(find.text('4'), findsOneWidget);
      expect(find.byType(RichText), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(figure('5'));
      expect(find.byType(RichText), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 160));
      await tester.pumpWidget(figure('6'));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('5'), findsNothing);
    });

    testWidgets('reduced motion: a cut', (tester) async {
      await tester.pumpWidget(figure('5h 40m', reduced: true));
      await tester.pumpWidget(figure('5h 39m', reduced: true));
      await tester.pump();
      expect(find.text('5h 40m'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('CountUp', () {
    testWidgets('counts up over 600 ms at the final width', (tester) async {
      await _pump(tester, CountUp(value: 188, style: IqText.figure));
      final width = tester.getSize(find.byType(CountUp)).width;
      expect(find.text('0'), findsOneWidget);
      // It starts once seen, on the frame after the first.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('${(188 * _eo(0.5)).round()}'), findsOneWidget);
      expect(tester.getSize(find.byType(CountUp)).width, width);
      await tester.pump(const Duration(milliseconds: 301));
      expect(find.text('188'), findsOneWidget);
      expect(tester.getSize(find.byType(CountUp)).width, width);
    });

    testWidgets('reduced motion: the final figure at once', (tester) async {
      await _pump(
        tester,
        CountUp(value: 188, style: IqText.figure),
        reduced: true,
      );
      expect(find.text('188'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('Collapse', () {
    Widget fold({required bool open, bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Collapse(open: open, child: _box),
        ),
      ),
    );

    double height(WidgetTester tester) =>
        tester.getSize(find.byType(Collapse)).height;

    testWidgets('folds away in 200 ease-in and unfolds in 240', (tester) async {
      await tester.pumpWidget(fold(open: true));
      expect(height(tester), 20);
      await tester.pumpWidget(fold(open: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(height(tester), closeTo(20 * (1 - _ei(0.5)), 0.01));
      await tester.pump(const Duration(milliseconds: 101));
      expect(height(tester), 0);
      await tester.pumpWidget(fold(open: true));
      await tester.pump(const Duration(milliseconds: 120));
      expect(height(tester), closeTo(20 * _eo(0.5), 0.01));
      await tester.pumpAndSettle();
      expect(height(tester), 20);
    });

    testWidgets('reduced motion: a cut', (tester) async {
      await tester.pumpWidget(fold(open: true, reduced: true));
      await tester.pumpWidget(fold(open: false, reduced: true));
      await tester.pump();
      expect(height(tester), 0);
    });
  });

  group('FadeThrough', () {
    Widget swap(String name) => MaterialApp(
      home: FadeThrough(
        child: SizedBox(key: ValueKey(name), width: 100, height: 20),
      ),
    );

    double fade(WidgetTester tester, String name) => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byKey(ValueKey(name)),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;

    testWidgets('out by 40%, in from 20%, 200 ms', (tester) async {
      await tester.pumpWidget(swap('old'));
      await tester.pumpWidget(swap('new'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        fade(tester, 'old'),
        closeTo(1 - FadeThroughCurves.outgoing.transform(0.25), 0.01),
      );
      expect(
        fade(tester, 'new'),
        closeTo(FadeThroughCurves.incoming.transform(0.25), 0.01),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(fade(tester, 'old'), closeTo(0, 0.001));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('old')), findsNothing);
      expect(fade(tester, 'new'), 1);
    });
  });

  group('FirstSeen', () {
    testWidgets('fires once, when half the child scrolls into view', (
      tester,
    ) async {
      var seen = 0;
      final visible = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ListView(
            children: [
              const SizedBox(height: 700),
              FirstSeen(
                onSeen: () => seen++,
                onVisible: visible.add,
                child: const SizedBox(height: 100),
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(seen, 0);
      expect(visible, [false]);
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(300);
      await tester.pump();
      await tester.pump();
      expect(seen, 1);
      expect(visible, [false, true]);
      tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(0);
      await tester.pump();
      await tester.pump();
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(300);
      await tester.pump();
      await tester.pump();
      expect(seen, 1);
      expect(visible, [false, true, false, true]);
    });
  });

  group('PulseScope', () {
    Color halo(WidgetTester tester, int index) {
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(IqCountdown).at(index),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is DecoratedBox &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).shape == BoxShape.circle,
              ),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).color!;
    }

    testWidgets('two Hot countdowns: only one pulses', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PulseScope(
            child: Column(children: [IqCountdown(), IqCountdown()]),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final first = halo(tester, 0);
      final second = halo(tester, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(halo(tester, 0), isNot(first));
      expect(halo(tester, 1), second);
      expect(second.a, closeTo(IqOpacity.haloStill, 0.01));
    });

    testWidgets('loops stop under reduced motion and with tickers off', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: IqCountdown())),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(
        const MaterialApp(
          home: TickerMode(enabled: false, child: Center(child: IqCountdown())),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}

double _eo(double t) => IqCurves.easeOut.transform(t);
double _ei(double t) => IqCurves.easeIn.transform(t);

Future<void> _pumpTop(
  WidgetTester tester,
  Widget child, {
  bool reduced = false,
  int key = 1,
}) {
  return tester.pumpWidget(
    MediaQuery(
      key: ValueKey('top $key'),
      data: MediaQueryData(disableAnimations: reduced),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}
