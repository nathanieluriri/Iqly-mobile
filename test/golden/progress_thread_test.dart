import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/progress_thread.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqProgressThreadState.values) {
    testWidgets('${state.name} state', (tester) async {
      await expectComponentGolden(
        tester,
        'progress_thread_${state.name}',
        SizedBox(width: 358, child: IqProgressThread(state: state)),
        size: const Size(358, 32),
      );
    });
  }
}
