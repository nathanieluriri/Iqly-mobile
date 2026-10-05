import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/notification.dart';

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  group('the unread dot', () {
    Widget row(bool unread) => MaterialApp(
      home: Scaffold(
        body: IqNotification(unread: unread, highlightDelay: Duration.zero),
      ),
    );

    double scale(WidgetTester tester, [Finder? dot]) =>
        tester.widget<AnimatedScale>(dot ?? find.byType(AnimatedScale)).scale;

    double shown(WidgetTester tester, [Finder? dot]) => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: dot ?? find.byType(AnimatedScale),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    testWidgets('shrinks away over 120 ms ease-in once read', (tester) async {
      await tester.pumpWidget(row(true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(row(false));
      expect(scale(tester), 0);
      await tester.pump(const Duration(milliseconds: 60));
      expect(shown(tester), inExclusiveRange(0.5, 1));
      await tester.pump(const Duration(milliseconds: 60));
      expect(shown(tester), 0);
    });

    testWidgets('reduced motion: gone at once', (tester) async {
      _reduce(tester);
      await tester.pumpWidget(row(true));
      await tester.pumpWidget(row(false));
      await tester.pump();
      expect(shown(tester), 0);
    });
  });
}
