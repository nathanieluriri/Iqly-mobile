import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/meta.dart';
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

  testWidgets('a Deadline chip, as the B4 frames set it (35:24)', (
    tester,
  ) async {
    await expectComponentGolden(
      tester,
      'submission_card_deadline',
      const SizedBox(
        width: 358,
        child: IqSubmissionCard(
          statusKind: IqMetaKind.deadline,
          statusLabel: 'Closes in 20 days',
          sent: 'Sent 1 day ago',
        ),
      ),
      size: const Size(358, 99),
    );
  });

  testWidgets('a long chip wraps the sent line under it (324:14520)', (
    tester,
  ) async {
    await expectComponentGolden(
      tester,
      'submission_card_wrapped',
      const SizedBox(
        width: 358,
        child: IqSubmissionCard(
          status: IqSubmissionCardStatus.notSelected,
          statusLabel: 'Didn’t pass screening',
          sent: 'Sent 20 days ago',
        ),
      ),
      size: const Size(358, 123),
    );
  });
}
