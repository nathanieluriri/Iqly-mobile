import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';

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
}
