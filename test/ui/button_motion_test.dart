import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/core/motion.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/button.dart';
import 'package:iqly_mobile/ui/sticker.dart';

void _reduce(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pump(WidgetTester tester, IqButtonKind kind) => tester.pumpWidget(
  MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: Center(
        child: IqButton(
          label: 'Send proof',
          kind: kind,
          showIcon: false,
          width: 358,
          onTap: () {},
        ),
      ),
    ),
  ),
);

Color _fill(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(AnimatedContainer),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .color!;

Color _ink(WidgetTester tester) =>
    tester.widget<Text>(find.text('Send proof')).style!.color!;

Color _sticker(WidgetTester tester) =>
    tester.widget<Sticker>(find.byType(Sticker)).color;

void main() {
  testWidgets('Secondary to Primary crosses fill, ink and sticker over '
      '160 ms ease-out', (tester) async {
    await _pump(tester, IqButtonKind.secondary);
    expect(_fill(tester), IqColors.card);
    expect(_sticker(tester), IqColors.brandLine2);

    await _pump(tester, IqButtonKind.primary);
    await tester.pump(const Duration(milliseconds: 80));
    final t = IqCurves.easeOut.transform(0.5);
    expect(_fill(tester), Color.lerp(IqColors.card, IqColors.brand, t));
    expect(_ink(tester), Color.lerp(IqColors.brand, IqColors.primaryFg, t));
    expect(
      _sticker(tester),
      Color.lerp(IqColors.brandLine2, IqColors.accent, t),
    );

    await tester.pump(const Duration(milliseconds: 80));
    expect(_fill(tester), IqColors.brand);
    expect(_ink(tester), IqColors.primaryFg);
    expect(_sticker(tester), IqColors.accent);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('back to Secondary crosses the same way', (tester) async {
    await _pump(tester, IqButtonKind.primary);
    await _pump(tester, IqButtonKind.secondary);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_fill(tester), isNot(IqColors.brand));
    expect(_fill(tester), isNot(IqColors.card));
    await tester.pumpAndSettle();
    expect(_fill(tester), IqColors.card);
    expect(_sticker(tester), IqColors.brandLine2);
  });

  testWidgets('reduced motion: the new kind at once', (tester) async {
    _reduce(tester);
    await _pump(tester, IqButtonKind.secondary);
    await _pump(tester, IqButtonKind.primary);
    await tester.pump();
    expect(_fill(tester), IqColors.brand);
    expect(_ink(tester), IqColors.primaryFg);
    expect(_sticker(tester), IqColors.accent);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
