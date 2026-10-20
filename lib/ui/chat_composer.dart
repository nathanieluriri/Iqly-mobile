import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'chat_header.dart' show IqChatRoundButton;
import 'field.dart';
import 'icon.dart';
import 'pressable.dart';
import 'sticker.dart';

enum IqChatComposerState { empty, typed }

/// Exp/ChatComposer: the reply bar under a thread. Attach (+) on the left,
/// the Reply field, and the ink disc on its sticker: the mic for a voice
/// note while nothing is typed, the arrow to send once something is.
class IqChatComposer extends StatelessWidget {
  const IqChatComposer({
    super.key,
    this.state = IqChatComposerState.empty,
    this.placeholder = 'Write to support',
    this.controller,
    this.onAttach,
    this.onSend,
    this.onVoiceNote,
    this.sending = false,
  });

  final IqChatComposerState state;
  final String placeholder;
  final TextEditingController? controller;
  final VoidCallback? onAttach;
  final VoidCallback? onSend;
  final VoidCallback? onVoiceNote;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final typed = state == IqChatComposerState.typed;
    final action = sending ? null : (typed ? onSend : onVoiceNote);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s3,
        IqSpace.s2,
        IqSpace.s3,
        IqSpace.s2p5,
      ),
      decoration: const BoxDecoration(
        color: IqColors.bg,
        border: Border(top: BorderSide(color: IqColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IqChatRoundButton(
            icon: IqIcons.plus,
            semanticLabel: 'Attach',
            onTap: sending ? null : onAttach,
          ),
          const SizedBox(width: IqSpace.s2),
          Expanded(
            child: IqField(
              label: 'Reply',
              value: placeholder,
              controller: controller,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
            ),
          ),
          const SizedBox(width: IqSpace.s2),
          IqPressable(
            semanticLabel: typed ? 'Send' : 'Voice note',
            onTap: action,
            builder: (context, pressed) => SizedBox.square(
              dimension: 44,
              child: Sticker(
                radius: 22,
                pressed: pressed,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pressed ? IqColors.brandDark : IqColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: IqIcon(
                    typed ? IqIcons.arrow : IqIcons.mic,
                    size: 22,
                    color: IqColors.primaryFg,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
