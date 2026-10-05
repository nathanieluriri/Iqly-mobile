import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/gift_button.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final shine in IqGiftButtonShine.values) {
    testWidgets('shine ${shine.name}', (tester) async {
      await expectComponentGolden(
        tester,
        'gift_button_${shine.name}',
        IqGiftButton(shine: shine),
        size: const Size(44, 44),
      );
    });
  }

  testWidgets('the twinkle runs through every keyframe once', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: IqGiftButton(twinkle: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
