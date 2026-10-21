import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/biz_crumb.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqBizCrumbState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'biz_crumb_${state.name}',
        IqBizCrumb(label: 'Discover', state: state),
        size: const Size(120, 44),
      );
    });
  }
}
