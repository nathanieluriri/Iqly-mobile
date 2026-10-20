import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

enum IqChatPillKind { date, unread, system, pinned }

/// Exp/ChatPill: a line on the chat canvas. Date, Unread and System are
/// centred pills (Unread in Mob/Small Strong); Pinned is the note at the
/// top of a business thread, a card of radius 10 in the full width.
class IqChatPill extends StatelessWidget {
  const IqChatPill({
    super.key,
    this.kind = IqChatPillKind.date,
    this.label = 'Today',
  });

  final IqChatPillKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pinned = kind == IqChatPillKind.pinned;
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: kind == IqChatPillKind.unread
          ? IqText.smallStrong.copyWith(color: IqColors.fg)
          : IqText.small.copyWith(color: IqColors.fg2),
    );
    return Container(
      padding: pinned
          ? const EdgeInsets.symmetric(horizontal: IqSpace.s3, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: IqSpace.s3, vertical: 4),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(pinned ? IqRadius.lg : 999),
        boxShadow: IqShadows.xs,
      ),
      child: text,
    );
  }
}
