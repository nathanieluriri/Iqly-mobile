import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/chat_media.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final kind in IqChatMediaKind.values) {
    for (final tone in IqChatMediaTone.values) {
      testWidgets('${kind.name} ${tone.name}', (tester) async {
        await expectComponentGolden(
          tester,
          'chat_media_${kind.name}_${tone.name}',
          IqChatMedia(
            kind: kind,
            tone: tone,
            width: kind == IqChatMediaKind.file ? 240 : 210,
            image: kind == IqChatMediaKind.image
                ? Image.asset(
                    'assets/samples/support/withdrawals-screenshot.jpg',
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          size: switch (kind) {
            IqChatMediaKind.image => const Size(210, 172),
            IqChatMediaKind.voice => const Size(182, 56),
            IqChatMediaKind.file => const Size(240, 53),
          },
          background: tone == IqChatMediaTone.ink
              ? IqColors.brand
              : IqColors.card,
        );
      });
    }
  }
}
