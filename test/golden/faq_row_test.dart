import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/faq_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('faq_row', (tester) async {
    await expectComponentGolden(
      tester,
      'faq_row',
      const SizedBox(width: 358, child: IqFaqRow()),
      size: const Size(358, 56),
    );
  });
}
