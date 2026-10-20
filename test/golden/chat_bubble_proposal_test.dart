import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/chat_bubble_proposal.dart';
import 'package:iqly_mobile/ui/chat_ticks.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final from in IqChatBubbleProposalFrom.values) {
    for (final tail in IqChatBubbleProposalTail.values) {
      for (final layout in IqChatBubbleProposalLayout.values) {
        final you = from == IqChatBubbleProposalFrom.you;
        final name =
            'chat_bubble_proposal_${from.name}_tail_${tail.name}_'
            '${layout.name}';
        testWidgets(name, (tester) async {
          await expectComponentGolden(
            tester,
            name,
            IqChatBubbleProposal(
              from: from,
              tail: tail,
              layout: layout,
              body: you
                  ? 'I still can’t see it in my bank app.'
                  : 'Thanks for the voice note, Adaeze.',
              time: '6:49 pm',
              sender: you || layout == IqChatBubbleProposalLayout.inline
                  ? null
                  : 'iQLY support',
              showSticker: true,
              ticks: you ? IqChatTicksState.read : null,
            ),
            size: const Size(330, 96),
            background: IqColors.secondary,
          );
        });
      }
    }
  }
}
