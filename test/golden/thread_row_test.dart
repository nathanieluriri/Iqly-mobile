import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/support_sticker.dart';
import 'package:iqly_mobile/ui/thread_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqThreadRowState.values) {
    testWidgets('iQLY ${state.name}', (tester) async {
      final resolved = state == IqThreadRowState.resolved;
      await expectComponentGolden(
        tester,
        'thread_row_iqly_${state.name}',
        SizedBox(
          width: 358,
          child: IqThreadRow(
            state: state,
            avatar: const IqSupportSticker(),
            preview: resolved
                ? 'You: Here is a clearer one.'
                : 'The reference on the receipt is the one Access Bank needs.',
            count: 2,
          ),
        ),
        size: Size(358, resolved ? 95 : 85),
      );
    });
  }
}
