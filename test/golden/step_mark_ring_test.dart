import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/step_mark.dart';
import 'package:iqly_mobile/ui/step_mark_ring.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final step in IqStepMarkStep.values) {
    final name = 'step_mark_ring_${step.name}';
    testWidgets(name, (tester) async {
      await expectComponentGolden(
        tester,
        name,
        IqStepMarkRing(step: step),
        size: Size(step == IqStepMarkStep.single ? 44 : 80, 44),
      );
    });
  }
}
