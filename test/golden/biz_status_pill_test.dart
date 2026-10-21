import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/biz_status_pill.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final status in IqBizStatusPillStatus.values) {
    testWidgets(status.name, (tester) async {
      await expectComponentGolden(
        tester,
        'biz_status_pill_${status.name}',
        IqBizStatusPill(status: status),
        size: const Size(100, 22),
      );
    });
  }
}
