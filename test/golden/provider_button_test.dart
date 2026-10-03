import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/provider_button.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final kind in IqProviderButtonKind.values) {
    final name = 'provider_button_${kind.name}';
    testWidgets(name, (tester) async {
      await expectComponentGolden(
        tester,
        name,
        IqProviderButton(kind: kind, onTap: () {}),
        size: const Size(362, 60),
      );
    });
  }

  testWidgets('provider_button_email_pressed', (tester) async {
    await expectPressedComponentGolden(
      tester,
      'provider_button_email_pressed',
      IqProviderButton(kind: IqProviderButtonKind.email, onTap: () {}),
      size: const Size(362, 60),
    );
  });

  testWidgets('taps reach onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IqProviderButton(onTap: () => taps++)),
      ),
    );
    await tester.tap(find.byType(IqProviderButton));
    expect(taps, 1);
  });
}
