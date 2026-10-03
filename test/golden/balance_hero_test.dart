import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/balance_hero.dart';
import 'package:iqly_mobile/ui/button.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('default', (tester) async {
    await expectComponentGolden(
      tester,
      'balance_hero',
      stillMotion(
        SizedBox(width: 358, child: IqBalanceHero(onWithdraw: () {})),
      ),
      size: const Size(358, 208),
    );
  });

  testWidgets('figureBuilder draws the four figures', (tester) async {
    final drawn = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: stillMotion(
            SizedBox(
              width: 358,
              child: IqBalanceHero(
                figureBuilder: (text, style) {
                  drawn.add(text);
                  return Text(text, style: style);
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(drawn, ['₦12,500', '.00', '₦10,000.00', '₦62,500.00']);
  });

  testWidgets('withdraw reaches onWithdraw', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: stillMotion(
            SizedBox(
              width: 358,
              child: IqBalanceHero(onWithdraw: () => taps++),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IqButton));
    expect(taps, 1);
  });
}
