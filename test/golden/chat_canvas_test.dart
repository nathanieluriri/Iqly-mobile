import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/chat_canvas.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('phone size', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_canvas_phone',
      const SizedBox(
        width: 390,
        height: 574,
        child: IqChatCanvas(child: SizedBox.shrink()),
      ),
      size: const Size(390, 574),
      padding: 0,
    );
  });
}
