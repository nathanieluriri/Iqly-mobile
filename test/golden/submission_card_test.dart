import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/submission_card.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final status in IqSubmissionCardStatus.values) {
    testWidgets('${status.name} status', (tester) async {
      await expectComponentGolden(
        tester,
        'submission_card_${status.name}',
        SizedBox(width: 358, child: IqSubmissionCard(status: status)),
        size: const Size(358, 99),
      );
    });
  }
}
