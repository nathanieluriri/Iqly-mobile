import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/step_mark.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final step in IqStepMarkStep.values) {
    final name = 'step_mark_${step.name}';
    testWidgets(name, (tester) async {
      await expectComponentGolden(
        tester,
        name,
        SizedBox(width: 358, child: IqStepMark(step: step)),
        size: const Size(358, 6),
      );
    });
  }
}
