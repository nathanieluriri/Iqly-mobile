import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/faq_sheet.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('faq_sheet', (tester) async {
    await expectComponentGolden(
      tester,
      'faq_sheet',
      const SizedBox(width: 390, child: IqFaqSheet()),
      size: const Size(390, 300),
      padding: 0,
    );
  });

  test('the answer says the business, never brand', () {
    expect(const IqFaqSheet().answer, isNot(contains('brand')));
  });
}
