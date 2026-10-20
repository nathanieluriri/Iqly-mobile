import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/chat_ticks.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqChatTicksState.values) {
    testWidgets('${state.name} state', (tester) async {
      await expectComponentGolden(
        tester,
        'chat_ticks_${state.name}',
        IqChatTicks(state: state),
        size: const Size(22, 16),
        background: IqColors.brand,
      );
    });
  }
}
