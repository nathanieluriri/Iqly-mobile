import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/chat_pill.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  const labels = {
    IqChatPillKind.date: 'Today',
    IqChatPillKind.unread: '2 unread messages',
    IqChatPillKind.system: 'iQLY support stepped in',
    IqChatPillKind.pinned:
        'Orchid Foods answers here. iQLY support can see this chat and '
        'steps in if there’s no answer in 2 days.',
  };

  for (final kind in IqChatPillKind.values) {
    testWidgets('${kind.name} kind', (tester) async {
      await expectComponentGolden(
        tester,
        'chat_pill_${kind.name}',
        SizedBox(
          width: kind == IqChatPillKind.pinned ? 354 : null,
          child: IqChatPill(kind: kind, label: labels[kind]!),
        ),
        size: Size(kind == IqChatPillKind.pinned ? 354 : 180, 52),
        background: IqColors.secondary,
      );
    });
  }
}
