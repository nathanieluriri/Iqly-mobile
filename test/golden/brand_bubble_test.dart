import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/brand_bubble.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqBrandBubbleState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'brand_bubble_${state.name}',
        IqBrandBubble(state: state),
        size: const Size(88, 94),
      );
    });
  }

  testWidgets('taps reach onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IqBrandBubble(onTap: () => taps++)),
      ),
    );
    await tester.tap(find.byType(IqBrandBubble));
    expect(taps, 1);
  });
}
