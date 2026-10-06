import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/receipt_card.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('completed', (tester) async {
    await expectComponentGolden(
      tester,
      'receipt_card_completed',
      const IqReceiptCard(),
      size: const Size(358, 261),
    );
  });

  testWidgets('pending', (tester) async {
    await expectComponentGolden(
      tester,
      'receipt_card_pending',
      const IqReceiptCard(status: 'Pending'),
      size: const Size(358, 261),
    );
  });

  testWidgets('failed', (tester) async {
    await expectComponentGolden(
      tester,
      'receipt_card_failed',
      const IqReceiptCard(status: 'Failed'),
      size: const Size(358, 261),
    );
  });

  testWidgets('tracker hides the amount row', (tester) async {
    await expectComponentGolden(
      tester,
      'receipt_card_no_amount',
      const IqReceiptCard(status: 'pending', showAmount: false),
      size: const Size(358, 216),
    );
  });

  testWidgets('failed receipt draws no tag (B14 194:9835)', (tester) async {
    await expectComponentGolden(
      tester,
      'receipt_card_no_status',
      const IqReceiptCard(
        to: 'Access Bank ••6789',
        reference: 'IQ-WD-240922-3C7Q',
        date: '11 days ago, 2:05 pm',
        status: 'Failed',
        showAmount: false,
        showStatus: false,
      ),
      size: const Size(358, 212),
    );
    expect(find.text('Failed'), findsNothing);
    expect(tester.getSize(find.byType(IqReceiptCard)).height, 212);
  });

  test('status words map to tones', () {
    expect(IqReceiptCard.toneOf('completed'), IqReceiptCardTone.ok);
    expect(IqReceiptCard.toneOf('processing'), IqReceiptCardTone.warn);
    expect(IqReceiptCard.toneOf('Pending'), IqReceiptCardTone.warn);
    expect(IqReceiptCard.toneOf('reversed'), IqReceiptCardTone.err);
  });
}
