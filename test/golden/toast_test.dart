import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/toast.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  const messages = {
    IqToastKind.success: 'Code copied',
    IqToastKind.error: 'Max 3 interests. Unselect one first.',
  };

  for (final kind in IqToastKind.values) {
    testWidgets(kind.name, (tester) async {
      await expectComponentGolden(
        tester,
        'toast_${kind.name}',
        SizedBox(
          width: 358,
          child: IqToast(message: messages[kind]!, kind: kind),
        ),
        size: const Size(358, 52),
      );
    });
  }
}
