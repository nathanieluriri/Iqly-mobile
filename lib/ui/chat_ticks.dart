import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';

enum IqChatTicksState { saved, read }

/// Exp/ChatTicks: under the person's own message. Saved is one tick on the
/// ink bubble at 70%; Read, once the other side has opened the thread since
/// (the API's `readBy`), two accent ticks overlapping by 10.
class IqChatTicks extends StatelessWidget {
  const IqChatTicks({super.key, this.state = IqChatTicksState.read});

  final IqChatTicksState state;

  @override
  Widget build(BuildContext context) {
    if (state == IqChatTicksState.saved) {
      return Opacity(
        opacity: 0.7,
        child: IqIcon(IqIcons.check, size: 16, color: IqColors.sidebarFg),
      );
    }
    return const SizedBox(
      width: 22,
      height: 16,
      child: Stack(
        children: [
          IqIcon(IqIcons.check, size: 16, color: IqColors.accent),
          Positioned(
            left: 6,
            child: IqIcon(IqIcons.check, size: 16, color: IqColors.accent),
          ),
        ],
      ),
    );
  }
}
