import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/continue_card.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('continue_card', (tester) async {
    await expectComponentGolden(
      tester,
      'continue_card',
      const SizedBox(width: 358, child: IqContinueCard()),
      size: const Size(358, 80),
    );
  });
}
