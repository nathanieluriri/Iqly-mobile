import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/activity_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('award', (tester) async {
    await expectComponentGolden(
      tester,
      'activity_row_award',
      const SizedBox(width: 358, child: IqActivityRowAward()),
      size: const Size(358, 64),
    );
  });

  for (final status in ['pending', 'completed', 'failed']) {
    testWidgets('withdrawal $status', (tester) async {
      await expectComponentGolden(
        tester,
        'activity_row_withdrawal_$status',
        SizedBox(width: 358, child: IqActivityRowWithdrawal(status: status)),
        size: const Size(358, 65),
      );
    });
  }

  test('status words map to the Badge tones', () {
    expect(
      IqActivityRowWithdrawal.toneOf('processing'),
      IqActivityRowStatusTone.secondary,
    );
    expect(
      IqActivityRowWithdrawal.toneOf('completed'),
      IqActivityRowStatusTone.standard,
    );
    expect(
      IqActivityRowWithdrawal.toneOf('reversed'),
      IqActivityRowStatusTone.destructive,
    );
  });

  testWidgets('taps reach onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IqActivityRowAward(onTap: () => taps++)),
      ),
    );
    await tester.tap(find.byType(IqActivityRowAward));
    expect(taps, 1);
  });
}
