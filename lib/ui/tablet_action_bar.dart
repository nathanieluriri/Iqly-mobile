import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// Exp/Tablet/ActionBar (local, sync to DS; 1807:34533): the bottom action
/// bar of the portrait brief and submit pages, pinned above the home
/// indicator and the keyboard. A summary on the left (the reward, or the
/// step) and the actions on the right, 12 apart; one primary at most.
class IqTabletActionBar extends StatelessWidget {
  const IqTabletActionBar({
    super.key,
    required this.title,
    required this.caption,
    required this.actions,
  });

  final String title;
  final String caption;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: IqSpace.s8,
        vertical: IqSpace.s4,
      ),
      decoration: const BoxDecoration(
        color: IqColors.card,
        border: Border(top: BorderSide(color: IqColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.figureSmall.copyWith(color: IqColors.fg),
                ),
                const SizedBox(height: IqSpace.s1),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqWebText.metaCaption.copyWith(color: IqColors.fg2),
                ),
              ],
            ),
          ),
          const SizedBox(width: IqSpace.s4),
          for (final (i, action) in actions.indexed) ...[
            if (i > 0) const SizedBox(width: IqSpace.s3),
            action,
          ],
        ],
      ),
    );
  }
}
