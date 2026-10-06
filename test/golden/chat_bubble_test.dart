import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/chat_bubble.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('from you', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_bubble_you',
      const SizedBox(width: 358, child: IqChatBubble()),
      size: const Size(358, 114),
    );
  });

  testWidgets('from support', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_bubble_support',
      const SizedBox(
        width: 358,
        child: IqChatBubble(
          from: IqChatBubbleFrom.support,
          body:
              'Thanks, Adaeze. The recording shows the save at 2:11 pm and '
              'Kudi Box has now confirmed it. ₦1,500.00 is in your wallet. '
              'Nothing else to do.',
          time: 'Today, 3:05 pm',
        ),
      ),
      size: const Size(358, 171),
    );
  });

  testWidgets('with attachment', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_bubble_you_attachment',
      stillMotion(
        const SizedBox(width: 358, child: IqChatBubble(showAttachment: true)),
      ),
      size: const Size(358, 391),
    );
  });

  testWidgets('a new bubble fades in', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(width: 358, child: IqChatBubble())),
      ),
    );
    final fade = find.descendant(
      of: find.byType(IqChatBubble),
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(fade.first).opacity.value, 0);
    await tester.pumpAndSettle();
    expect(tester.widget<FadeTransition>(fade.first).opacity.value, 1);
  });

  testWidgets('a new bubble’s time stamp fades in with it, on its clock', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(width: 358, child: IqChatBubble())),
      ),
    );
    double seen(Finder finder) {
      var opacity = 1.0;
      for (final fade in tester.widgetList<FadeTransition>(
        find.ancestor(of: finder, matching: find.byType(FadeTransition)),
      )) {
        opacity *= fade.opacity.value;
      }
      return opacity;
    }

    final stamp = find.text('Today, 2:20 pm');
    final body = find.textContaining('I did all three steps');
    expect(seen(body), 0);
    expect(seen(stamp), 0);
    for (var at = 16; at <= 240; at += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(seen(stamp), closeTo(seen(body), 0.001), reason: 'at $at ms');
    }
    await tester.pumpAndSettle();
    expect(seen(stamp), 1);
  });
}
