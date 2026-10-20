import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';

/// Exp/ChatResolvedBar: over the composer of a resolved thread, the ok tile
/// and why it still takes a message.
class IqChatResolvedBar extends StatelessWidget {
  const IqChatResolvedBar({
    super.key,
    this.title = 'This chat is resolved',
    this.hint = 'Send a message to open it again',
  });

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s4,
        vertical: IqSpace.s3,
      ),
      decoration: const BoxDecoration(
        color: IqColors.bg,
        border: Border(top: BorderSide(color: IqColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: IqColors.okSoft,
              shape: BoxShape.circle,
            ),
            child: const IqIcon(IqIcons.success, size: 20, color: IqColors.ok),
          ),
          const SizedBox(width: IqSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                ),
                Text(hint, style: IqText.small.copyWith(color: IqColors.fg3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
