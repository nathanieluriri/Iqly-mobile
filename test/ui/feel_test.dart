import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/edge_haptics.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/toast.dart';

const _light = 'HapticFeedbackType.lightImpact';
const _medium = 'HapticFeedbackType.mediumImpact';
const _heavy = 'HapticFeedbackType.heavyImpact';

List<String> _haptics(WidgetTester tester) {
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

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildTheme(),
    home: Scaffold(body: Center(child: child)),
  ),
);

Widget _square({
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  String? hint,
  IqHaptics? haptic = IqHaptics.tap,
  bool tactile = true,
}) => IqPressable(
  onTap: onTap ?? () {},
  onLongPress: onLongPress,
  hint: hint,
  haptic: haptic,
  tactile: tactile,
  builder: (context, pressed) =>
      const SizedBox.square(key: ValueKey('face'), dimension: 100),
);

/// How much the pressable's paint is scaled, read from its paint transform.
double _paintScale(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(
    find.byKey(const ValueKey('face')),
  );
  final topLeft = box.localToGlobal(Offset.zero);
  final bottomRight = box.localToGlobal(box.size.bottomRight(Offset.zero));
  return (bottomRight.dx - topLeft.dx) / box.size.width;
}

void main() {
  group('IqPressable feel', () {
    testWidgets('a tap plays the light tap unless the target opts out', (
      tester,
    ) async {
      final haptics = _haptics(tester);
      await _pump(tester, _square());
      await tester.tap(find.byType(IqPressable));
      await tester.pump();
      expect(haptics, [_light]);

      await _pump(tester, _square(haptic: null));
      await tester.tap(find.byType(IqPressable));
      await tester.pump();
      expect(haptics, [_light]);
    });

    testWidgets('it sinks by 8 points across its longer side while held and '
        'springs back past rest on release', (tester) async {
      await _pump(tester, _square());
      expect(_paintScale(tester), 1);
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(IqPressable)),
      );
      await tester.pump();
      await tester.pump(IqDurations.press);
      expect(_paintScale(tester), closeTo(0.94, 0.001));

      await finger.up();
      await tester.pump(IqDurations.pressHold);
      var overshoot = 0.0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 11));
        overshoot = _paintScale(tester) > overshoot
            ? _paintScale(tester)
            : overshoot;
      }
      expect(overshoot, greaterThan(1));
      await tester.pumpAndSettle();
      expect(_paintScale(tester), 1);
    });

    testWidgets('a quick tap springs past rest too', (tester) async {
      await _pump(tester, _square());
      await tester.tap(find.byType(IqPressable));
      var overshoot = 0.0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 11));
        overshoot = _paintScale(tester) > overshoot
            ? _paintScale(tester)
            : overshoot;
      }
      expect(overshoot, greaterThan(1));
      await tester.pumpAndSettle();
      expect(_paintScale(tester), 1);
    });

    testWidgets('a target with its own designed press does not sink', (
      tester,
    ) async {
      await _pump(tester, _square(tactile: false));
      await tester.startGesture(tester.getCenter(find.byType(IqPressable)));
      await tester.pump();
      await tester.pump(IqDurations.press);
      expect(_paintScale(tester), 1);
    });

    testWidgets('holding shows the hint with the heavy hold', (tester) async {
      final haptics = _haptics(tester);
      await _pump(tester, _square(hint: 'Copy code ADAEZE24'));
      await tester.longPress(find.byType(IqPressable));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Copy code ADAEZE24'), findsOneWidget);
      expect(haptics, [_heavy]);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('holding runs the long press instead of the hint', (
      tester,
    ) async {
      final held = <String>[];
      await _pump(
        tester,
        _square(hint: 'Unused', onLongPress: () => held.add('held')),
      );
      await tester.longPress(find.byType(IqPressable));
      await tester.pumpAndSettle();
      expect(held, ['held']);
      expect(find.text('Unused'), findsNothing);
    });

    testWidgets('nothing to say means no hold and no buzz', (tester) async {
      final haptics = _haptics(tester);
      await _pump(tester, _square());
      await tester.longPress(find.byType(IqPressable));
      await tester.pumpAndSettle();
      expect(haptics, isNot(contains(_heavy)));
    });
  });

  group('EdgeHaptics', () {
    String edge() =>
        defaultTargetPlatform == TargetPlatform.android ? _heavy : _medium;

    Widget list({Axis axis = Axis.vertical}) => EdgeHaptics(
      child: ListView(
        scrollDirection: axis,
        children: [
          for (var i = 0; i < 30; i++)
            SizedBox(height: 60, width: 60, child: Text('$i')),
        ],
      ),
    );

    testWidgets('reaching an end plays one stop, on a drag or a fling; '
        'pushing past it stays quiet until the list leaves it', (tester) async {
      final haptics = _haptics(tester);
      await _pump(tester, list());
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);

      await tester.fling(find.byType(ListView), const Offset(0, -300), 8000);
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(haptics, [edge()]);

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(haptics, [edge()]);

      await tester.drag(find.byType(ListView), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(haptics, [edge()]);
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(haptics, [edge(), edge()]);

      await tester.fling(find.byType(ListView), const Offset(0, 300), 8000);
      await tester.pumpAndSettle();
      expect(position.pixels, position.minScrollExtent);
      expect(haptics, [edge(), edge(), edge()]);
    });

    testWidgets(
      'one stop on the frame a drag reaches the end, on clamping and '
      'bouncing physics',
      (tester) async {
        final haptics = _haptics(tester);
        await _pump(tester, list());
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        final finger = await tester.startGesture(
          tester.getCenter(find.byType(ListView)),
        );
        var reachedAt = -1;
        for (var i = 0; i < 30; i++) {
          await finger.moveBy(const Offset(0, -100));
          await tester.pump();
          if (reachedAt < 0 &&
              position.pixels >= position.maxScrollExtent - 0.5) {
            reachedAt = i;
            expect(haptics, [edge()]);
          }
        }
        await finger.up();
        await tester.pumpAndSettle();
        expect(reachedAt, greaterThanOrEqualTo(0));
        expect(haptics, [edge()]);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    testWidgets('a programmatic scroll to an end stays quiet', (tester) async {
      final haptics = _haptics(tester);
      await _pump(tester, list());
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      unawaited(
        position.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.linear,
        ),
      );
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
    });

    testWidgets('a list that pulls to refresh stops at its top too, and '
        'notes it for the pull; a drag that starts at the top stays quiet', (
      tester,
    ) async {
      final haptics = _haptics(tester);
      await _pump(tester, PullsToRefresh(child: list()));
      final gesture = PullsToRefresh.of(tester.element(find.byType(ListView)))!;
      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      expect(gesture.reachedTop, isFalse);

      await tester.fling(find.byType(ListView), const Offset(0, -300), 8000);
      await tester.pumpAndSettle();
      expect(haptics, [edge()]);
      expect(gesture.reachedTop, isFalse);
      await tester.fling(find.byType(ListView), const Offset(0, 300), 8000);
      await tester.pumpAndSettle();
      expect(haptics, [edge(), edge()]);
      expect(gesture.reachedTop, isTrue);

      await tester.drag(find.byType(ListView), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(gesture.reachedTop, isFalse);

      await _pump(tester, PullsToRefresh(child: list(axis: Axis.horizontal)));
      await tester.fling(find.byType(ListView), const Offset(-300, 0), 8000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ListView), const Offset(300, 0), 8000);
      await tester.pumpAndSettle();
      expect(haptics, [edge(), edge(), edge(), edge()]);
    });

    testWidgets('a list too short to scroll stays quiet', (tester) async {
      final haptics = _haptics(tester);
      await _pump(
        tester,
        EdgeHaptics(child: ListView(children: const [Text('one')])),
      );
      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
    });
  });

  group('IqToast', () {
    testWidgets('rises, holds for 2 s and leaves on its own', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => IqToast.show(
              context,
              'Max 3 interests. Unselect one first.',
              kind: IqToastKind.error,
            ),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(IqDurations.appear);
      expect(find.text('Max 3 interests. Unselect one first.'), findsOneWidget);
      await tester.pump(IqDurations.toast);
      await tester.pumpAndSettle();
      expect(find.text('Max 3 interests. Unselect one first.'), findsNothing);
    });

    Future<BuildContext> floored(
      WidgetTester tester, {
      bool floor = true,
      double keyboard = 0,
      bool reduced = false,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.reset);
      if (reduced) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            resizeToAvoidBottomInset: false,
            body: Column(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      ctx = context;
                      return const SizedBox.expand();
                    },
                  ),
                ),
                if (floor) const IqToastFloor(child: SizedBox(height: 100)),
                const SizedBox(height: 34),
              ],
            ),
          ),
        ),
      );
      return ctx;
    }

    double toastBottom(WidgetTester tester) =>
        tester.getBottomLeft(find.byType(IqToast)).dy;

    testWidgets('floats 24 above its screen\'s floor, or above the home '
        'indicator without one (1284:90206)', (tester) async {
      var ctx = await floored(tester);
      IqToast.show(ctx, 'Code copied');
      await tester.pump();
      await tester.pump(IqDurations.appear);
      expect(toastBottom(tester), 844 - 34 - 100 - 24);
      await tester.pumpAndSettle();

      ctx = await floored(tester, floor: false);
      IqToast.show(ctx, 'Code copied');
      await tester.pump();
      await tester.pump(IqDurations.appear);
      expect(toastBottom(tester), 844 - 34 - 24);
      await tester.pumpAndSettle();
    });

    testWidgets('rides above the keyboard while it is up', (tester) async {
      final ctx = await floored(tester, keyboard: 336);
      IqToast.show(ctx, 'Max 3 interests. Unselect one first.');
      await tester.pump();
      await tester.pump(IqDurations.appear);
      expect(toastBottom(tester), 844 - 336 - 24);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: no rise, and it still stays its 2 s', (
      tester,
    ) async {
      final ctx = await floored(tester, reduced: true);
      IqToast.show(ctx, 'Code copied');
      await tester.pump();
      await tester.pump(IqDurations.appear);
      expect(toastBottom(tester), 844 - 34 - 100 - 24);
      await tester.pump(IqDurations.toast - IqDurations.appear);
      expect(find.text('Code copied'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Code copied'), findsNothing);
    });

    testWidgets('a new toast replaces the one showing', (tester) async {
      late BuildContext ctx;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      );
      IqToast.show(ctx, 'Code copied');
      await tester.pump();
      IqToast.show(ctx, 'Link copied');
      await tester.pump();
      expect(find.text('Code copied'), findsNothing);
      expect(find.text('Link copied'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Link copied'), findsNothing);
    });
  });
}
