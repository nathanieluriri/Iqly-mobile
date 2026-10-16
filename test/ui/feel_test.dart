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
    Widget list() => EdgeHaptics(
      child: ListView(
        children: [
          for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('$i')),
        ],
      ),
    );

    testWidgets('a drag into the end plays one stop; a coast into it and a '
        'pull at the top stay quiet', (tester) async {
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
      expect(haptics, isEmpty);

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(haptics, [_medium]);
    });

    testWidgets(
      'one stop per drag, on clamping and bouncing physics',
      (tester) async {
        final haptics = _haptics(tester);
        await _pump(tester, list());
        final finger = await tester.startGesture(
          tester.getCenter(find.byType(ListView)),
        );
        for (var i = 0; i < 30; i++) {
          await finger.moveBy(const Offset(0, -100));
          await tester.pump();
        }
        await finger.up();
        await tester.pumpAndSettle();
        expect(haptics, [_medium]);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

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
