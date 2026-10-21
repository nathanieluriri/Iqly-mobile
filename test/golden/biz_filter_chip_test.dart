import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/biz_filter_chip.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqBizFilterChipState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'biz_filter_chip_${state.name}',
        IqBizFilterChip(label: 'Tier: Advanced', state: state),
        size: const Size(160, 44),
      );
    });
  }
}
