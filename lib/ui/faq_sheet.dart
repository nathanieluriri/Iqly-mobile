import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'chip.dart';
import 'icon.dart';
import 'pressable.dart';

/// Exp/FaqSheet: the bottom sheet for one FAQ. The question as the title,
/// the answer, a did-this-answer-it pair and the way to a person. It rises
/// over a scrim like Exp/ConfirmSheet; the scrim belongs to the route.
///
/// Figma over brief: the sample answer says "The brand"; the copy rule
/// (designer answer 38) makes it "The business".
/// Figma over brief: the home indicator placeholder becomes the OS inset (34 minimum).
class IqFaqSheet extends StatelessWidget {
  const IqFaqSheet({
    super.key,
    this.question = 'When do I get paid after a brief closes?',
    this.answer =
        'The business picks winners within a week of the close. Awards land '
        'in your wallet right after, and you can withdraw them to your bank.',
    this.helpful,
    this.onHelpful,
    this.onChat,
    this.showChat = true,
  });

  final String question;
  final String answer;

  /// The reader's pick, true for Yes and false for No.
  final bool? helpful;
  final ValueChanged<bool>? onHelpful;
  final VoidCallback? onChat;

  /// Not a Figma prop: a launch with no support to chat to leaves the link
  /// out.
  final bool showChat;

  static const double radius = 24;
  static const double homeIndicator = 34;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: IqSpace.s2, bottom: IqSpace.s1),
            child: Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: IqColors.line2,
                  borderRadius: BorderRadius.circular(IqRadius.full),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s5,
              IqSpace.s2p5,
              IqSpace.s5,
              IqSpace.s5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  question,
                  style: IqText.title.copyWith(color: IqColors.fg),
                ),
                const SizedBox(height: IqSpace.s2p5),
                Text(answer, style: IqText.body.copyWith(color: IqColors.fg2)),
                const SizedBox(height: IqSpace.s2p5),
                const SizedBox(
                  height: 1,
                  width: double.infinity,
                  child: ColoredBox(color: IqColors.line),
                ),
                const SizedBox(height: IqSpace.s2p5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Did this answer it?',
                        style: IqText.smallStrong.copyWith(color: IqColors.fg),
                      ),
                    ),
                    const SizedBox(width: IqSpace.s2),
                    _pick('Yes', true),
                    const SizedBox(width: IqSpace.s2),
                    _pick('No', false),
                  ],
                ),
                if (showChat) ...[
                  const SizedBox(height: IqSpace.s2p5),
                  IqPressable(
                    onTap: onChat,
                    semanticLabel: 'Still stuck? Chat with us',
                    builder: (context, pressed) => PressDim(
                      pressed: pressed,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Still stuck? Chat with us',
                            style: IqText.smallStrong.copyWith(
                              color: IqColors.brand,
                            ),
                          ),
                          const SizedBox(width: IqSpace.s1),
                          const IqIcon(
                            IqIcons.forward,
                            size: 16,
                            color: IqColors.brand,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: math.max(inset, homeIndicator)),
        ],
      ),
    );
  }

  Widget _pick(String label, bool value) {
    return IqChip(
      label: label,
      state: helpful == value ? IqChipState.selected : IqChipState.standard,
      onChanged: onHelpful == null ? null : (_) => onHelpful!(value),
    );
  }
}
