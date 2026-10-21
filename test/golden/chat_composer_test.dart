import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/chat_composer.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('empty state', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_composer_empty',
      const SizedBox(width: 390, child: IqChatComposer()),
      size: const Size(390, 81),
      padding: 0,
    );
  });

  testWidgets('typed state', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_composer_typed',
      SizedBox(
        width: 390,
        child: IqChatComposer(
          state: IqChatComposerState.typed,
          controller: TextEditingController(
            text: 'Thank you, I’ll do that now.',
          ),
        ),
      ),
      size: const Size(390, 81),
      padding: 0,
    );
  });

  testWidgets('recording state', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_composer_recording',
      const SizedBox(
        width: 390,
        child: IqChatComposer(
          state: IqChatComposerState.recording,
          recordTime: '0:07',
          slide: 0.3,
        ),
      ),
      size: const Size(390, 81),
      padding: 0,
    );
  });

  testWidgets('recording state, screen reader', (tester) async {
    await expectComponentGolden(
      tester,
      'chat_composer_recording_screen_reader',
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
          child: SizedBox(
            width: 390,
            child: IqChatComposer(
              state: IqChatComposerState.recording,
              recordTime: '0:07',
              onHoldStart: () {},
              onHoldEnd: () {},
              onHoldCancel: () {},
            ),
          ),
        ),
      ),
      size: const Size(390, 81),
      padding: 0,
    );
  });
}
