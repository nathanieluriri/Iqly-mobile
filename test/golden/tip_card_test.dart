import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/tip_card.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('tip_card', (tester) async {
    await expectComponentGolden(
      tester,
      'tip_card',
      const IqTipCard(),
      size: const Size(350, 240),
      padding: 28,
    );
  });

  testWidgets('the action reaches onAction', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IqTipCard(onAction: () => taps++)),
      ),
    );
    await tester.tap(find.text('OK, got it'));
    expect(taps, 1);
  });

  testWidgets('the action takes taps across a 44 pt strip', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: IqTipCard(onAction: () => taps++)),
        ),
      ),
    );
    final card = tester.getRect(find.byType(IqTipCard));
    await tester.tapAt(card.topLeft + const Offset(40, 158));
    await tester.tapAt(card.topLeft + const Offset(40, 198));
    expect(taps, 2);
  });
}
