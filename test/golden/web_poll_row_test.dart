import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/sample_cover.dart';
import 'package:iqly_mobile/ui/sample_logo.dart';
import 'package:iqly_mobile/ui/web_poll_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final status in IqWebPollRowStatus.values) {
    testWidgets(status.name, (tester) async {
      await expectComponentGolden(
        tester,
        'web_poll_row_${status.name}',
        SizedBox(
          width: 868,
          child: IqWebPollRow(
            business: 'Orchid Foods',
            question: 'Which flavour should we launch first?',
            detail: '1 poll · 3 questions · about 15 seconds',
            closes: 'Closes in 2 days',
            cover: const IqSampleCover(IqSampleLogoBrand.orchidFoods),
            logo: const IqSampleLogo(IqSampleLogoBrand.orchidFoods),
            status: status,
          ),
        ),
        size: const Size(868, 100),
      );
    });
  }
}
