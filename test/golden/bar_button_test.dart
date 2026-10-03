import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/bar_button.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('bar_button_default', (tester) async {
    await expectComponentGolden(
      tester,
      'bar_button_default',
      IqBarButton(onTap: () {}),
      size: const Size(390, 88),
    );
  });

  testWidgets('Disabled ignores taps', (tester) async {
    var taps = 0;
    for (final state in IqBarButtonState.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IqBarButton(state: state, onTap: () => taps++),
          ),
        ),
      );
      await tester.tap(find.byType(IqBarButton));
    }
    expect(taps, 1);
  });
}
