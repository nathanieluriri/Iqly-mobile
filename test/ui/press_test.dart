import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/chip.dart';
import 'package:iqly_mobile/ui/next_fab.dart';
import 'package:iqly_mobile/ui/pressable.dart';
import 'package:iqly_mobile/ui/sticker.dart';

const _light = 'HapticFeedbackType.lightImpact';
const _medium = 'HapticFeedbackType.mediumImpact';
const _heavy = 'HapticFeedbackType.heavyImpact';
const _select = 'HapticFeedbackType.selectionClick';

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

Future<void> _pump(WidgetTester tester, Widget child, {bool reduced = false}) {
  if (reduced) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  return tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('IqPressable', () {
    Widget target(List<bool> drawn, List<String> taps) => ListView(
      children: [
        IqPressable(
          onTap: () => taps.add('tap'),
          builder: (context, pressed) {
            drawn.add(pressed);
            return const SizedBox(height: 60);
          },
        ),
      ],
    );

    testWidgets('a quick tap in a scroll view still shows the press', (
      tester,
    ) async {
      final drawn = <bool>[];
      final taps = <String>[];
      await _pump(tester, target(drawn, taps));
      await tester.tap(find.byType(IqPressable));
      expect(taps, ['tap']);
      await tester.pump();
      expect(drawn.last, isTrue);
      await tester.pump(const Duration(milliseconds: 99));
      expect(drawn.last, isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(drawn.last, isFalse);
    });

    testWidgets('a held press lets go as the finger lifts', (tester) async {
      final drawn = <bool>[];
      await _pump(tester, target(drawn, []));
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(IqPressable)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(drawn.last, isTrue);
      await finger.up();
      await tester.pump();
      expect(drawn.last, isFalse);
    });

    testWidgets('reduced motion: the same hold', (tester) async {
      final drawn = <bool>[];
      await _pump(tester, target(drawn, []), reduced: true);
      await tester.tap(find.byType(IqPressable));
      await tester.pump();
      expect(drawn.last, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(drawn.last, isFalse);
    });

    testWidgets('a text link dims to .6, 100 in and 160 out', (tester) async {
      await _pump(
        tester,
        IqPressable(
          onTap: () {},
          builder: (context, pressed) => PressDim(
            pressed: pressed,
            child: const SizedBox(width: 80, height: 44),
          ),
        ),
      );
      double opacity() =>
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(IqPressable)),
      );
      await tester.pump();
      expect(opacity(), IqOpacity.pressed);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
        IqDurations.dim,
      );
      await finger.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(opacity(), 1);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
        IqDurations.release,
      );
    });
  });

  group('Sticker', () {
    Widget sticker({bool pressed = false, bool visible = true}) => Sticker(
      radius: 26,
      pressed: pressed,
      visible: visible,
      child: const SizedBox(key: ValueKey('pill'), width: 200, height: 52),
    );

    Offset pill(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const ValueKey('pill'))) -
        tester.getTopLeft(find.byType(Sticker));

    Opacity shadow(WidgetTester tester) => tester.widget<Opacity>(
      find.descendant(of: find.byType(Sticker), matching: find.byType(Opacity)),
    );

    Offset shadowAt(WidgetTester tester) {
      final shift = tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(Sticker),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation();
      return Offset(shift.x, shift.y);
    }

    testWidgets('drops 3,3 onto its shadow in 120, back in 160', (
      tester,
    ) async {
      await _pump(tester, sticker());
      await _pump(tester, sticker(pressed: true));
      await tester.pump(const Duration(milliseconds: 60));
      expect(pill(tester).dx, closeTo(3 * _eo(0.5), 0.01));
      expect(shadow(tester).opacity, closeTo(1 - _eo(0.5), 0.01));
      await tester.pump(const Duration(milliseconds: 61));
      expect(pill(tester), const Offset(3, 3));
      expect(shadow(tester).opacity, 0);

      await _pump(tester, sticker());
      await tester.pump(const Duration(milliseconds: 80));
      expect(pill(tester).dx, closeTo(3 * (1 - _eo(0.5)), 0.01));
      await tester.pump(const Duration(milliseconds: 81));
      expect(pill(tester), Offset.zero);
      expect(shadow(tester).opacity, 1);
    });

    testWidgets('peels out from under the pill, 200, and tucks back, 120', (
      tester,
    ) async {
      await _pump(tester, sticker(visible: false));
      expect(shadow(tester).opacity, 0);
      expect(shadowAt(tester), Offset.zero);
      await _pump(tester, sticker());
      await tester.pump(const Duration(milliseconds: 100));
      expect(shadow(tester).opacity, closeTo(_eo(0.5), 0.01));
      expect(shadowAt(tester).dx, closeTo(4 * _eo(0.5), 0.01));
      await tester.pump(const Duration(milliseconds: 101));
      expect(shadowAt(tester), const Offset(4, 4));

      await _pump(tester, sticker(visible: false));
      await tester.pump(const Duration(milliseconds: 60));
      expect(shadow(tester).opacity, closeTo(1 - _ei(0.5), 0.01));
      await tester.pump(const Duration(milliseconds: 61));
      expect(shadow(tester).opacity, 0);
    });

    testWidgets('reduced motion: nothing moves', (tester) async {
      await _pump(tester, sticker(), reduced: true);
      await _pump(tester, sticker(pressed: true), reduced: true);
      await tester.pump(const Duration(milliseconds: 200));
      expect(pill(tester), Offset.zero);
      expect(shadow(tester).opacity, 1);
      await _pump(tester, sticker(visible: false), reduced: true);
      await tester.pump();
      expect(shadow(tester).opacity, 0);
    });
  });

  group('Button', () {
    testWidgets('haptics: commit on Primary and Inverse, the heavy '
        'destructive on Danger, a light tap on Secondary and Ghost', (
      tester,
    ) async {
      final played = _haptics(tester);
      for (final kind in IqButtonKind.values) {
        await _pump(tester, IqButton(kind: kind, onTap: () {}));
        await tester.tap(find.byType(IqButton));
        await tester.pump(const Duration(milliseconds: 200));
      }
      const kinds = [_medium, _light, _heavy, _light, _medium];
      expect(played, kinds);

      await _pump(tester, IqButton(disabled: true, onTap: () {}));
      await tester.tap(find.byType(IqButton), warnIfMissed: false);
      await _pump(tester, IqNextFab(onTap: () {}));
      await tester.tap(find.byType(IqNextFab), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(played, kinds);

      await _pump(
        tester,
        IqNextFab(state: IqNextFabState.enabled, onTap: () {}),
      );
      await tester.tap(find.byType(IqNextFab));
      await tester.pump(const Duration(milliseconds: 200));
      await _pump(tester, IqChip(onChanged: (_) {}));
      await tester.tap(find.byType(IqChip));
      await tester.pump(const Duration(milliseconds: 200));
      expect(played, [...kinds, _medium, _select]);
    });

    testWidgets('Ghost dims instead of dropping', (tester) async {
      await _pump(
        tester,
        IqButton(kind: IqButtonKind.ghost, label: 'Skip', onTap: () {}),
      );
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(IqButton)),
      );
      await tester.pump();
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.descendant(
                of: find.byType(IqButton),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        IqOpacity.pressed,
      );
      await finger.up();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('the label and the spinner crossfade, 150', (tester) async {
      await _pump(tester, IqButton(label: 'Send', onTap: () {}));
      await _pump(tester, IqButton(label: 'Send', loading: true, onTap: () {}));
      await tester.pump(const Duration(milliseconds: 75));
      expect(find.text('Send'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 76));
      expect(find.text('Send'), findsNothing);
    });

    testWidgets('turning enabled crossfades the fill over 160', (tester) async {
      AnimatedContainer pill() => tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(IqButton),
          matching: find.byType(AnimatedContainer),
        ),
      );
      await _pump(tester, IqButton(disabled: true, onTap: () {}));
      await _pump(tester, IqButton(onTap: () {}));
      expect((pill().decoration! as BoxDecoration).color, IqColors.brand);
      expect(pill().duration, IqDurations.tick);
      expect(pill().curve, IqCurves.easeOut);
      await tester.pumpAndSettle();
      await _pump(tester, IqButton(disabled: true, onTap: () {}));
      expect(pill().duration, IqDurations.press);
      expect(pill().curve, IqCurves.easeIn);
    });
  });
}

double _eo(double t) => IqCurves.easeOut.transform(t);
double _ei(double t) => IqCurves.easeIn.transform(t);
