import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/pressable.dart';
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

  testWidgets('the card hugs its content and keeps the Figma gaps', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: IqTipCard())),
      ),
    );
    final card = tester.getRect(find.byType(IqTipCard));
    final action = tester.getRect(find.text('OK, got it'));
    // 36 + three title lines of 35.84 + 20 + hairline + 20 + 18 + 28.
    expect(card.height, closeTo(230.5, 0.5));
    expect(action.top - card.top, closeTo(184.5, 0.5));
    expect(card.bottom - action.bottom, 28);
  });

  testWidgets('the action takes taps across a 44 pt band', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: IqTipCard(onAction: () => taps++)),
        ),
      ),
    );
    final band = tester.getRect(
      find.ancestor(
        of: find.text('OK, got it'),
        matching: find.byType(IqPressable),
      ),
    );
    expect(band.height, 44);
    await tester.tapAt(band.topLeft + const Offset(20, 1));
    await tester.tapAt(band.bottomLeft + const Offset(20, -1));
    expect(taps, 2);
  });
}
