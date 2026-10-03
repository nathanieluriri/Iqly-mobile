import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/button.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  const size = Size(204, 56);

  for (final kind in IqButtonKind.values) {
    testWidgets('${kind.name} default', (tester) async {
      await expectComponentGolden(
        tester,
        'button_${kind.name}_default',
        IqButton(kind: kind, onTap: () {}),
        size: size,
      );
    });

    if (kind != IqButtonKind.ghost) {
      testWidgets('${kind.name} pressed', (tester) async {
        await expectPressedComponentGolden(
          tester,
          'button_${kind.name}_pressed',
          IqButton(kind: kind, onTap: () {}),
          size: size,
        );
      });
    }

    testWidgets('${kind.name} disabled', (tester) async {
      await expectComponentGolden(
        tester,
        'button_${kind.name}_disabled',
        IqButton(kind: kind, disabled: true, onTap: () {}),
        size: size,
      );
    });

    testWidgets('${kind.name} loading', (tester) async {
      await expectComponentGolden(
        tester,
        'button_${kind.name}_loading',
        stillMotion(IqButton(kind: kind, loading: true, onTap: () {})),
        size: size,
      );
    });
  }

  testWidgets('taps reach onTap, not while disabled or loading', (
    tester,
  ) async {
    var taps = 0;
    Future<void> tapWith(IqButton button) async {
      await tester.pumpWidget(MaterialApp(home: stillMotion(button)));
      await tester.tap(find.byType(IqButton), warnIfMissed: false);
      await tester.pump();
    }

    await tapWith(IqButton(onTap: () => taps++));
    await tapWith(IqButton(disabled: true, onTap: () => taps++));
    await tapWith(IqButton(loading: true, onTap: () => taps++));
    expect(taps, 1);
  });
}
