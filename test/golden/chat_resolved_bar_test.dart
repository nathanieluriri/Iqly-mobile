import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/chat_resolved_bar.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('resolved bar', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_resolved_bar',
      const SizedBox(width: 390, child: IqChatResolvedBar()),
      size: const Size(390, 64),
      padding: 0,
    );
  });
}
