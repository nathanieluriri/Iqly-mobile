import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'pressable.dart';

/// Exp/TipCard: the first-run tip over a dimmed screen, one headline, a
/// hairline and one text action (the only tap target). The scrim belongs
/// to the screen. Children sit where Figma pins them (the action overhangs
/// the 28 bottom padding, as in Figma).
///
/// Figma over brief: the component default action is "Ok, got it"; the screen overrides it to "OK, got it", used here.
class IqTipCard extends StatelessWidget {
  const IqTipCard({
    super.key,
    this.title = 'One shot per brief. Make it count.',
    this.action = 'OK, got it',
    this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 326,
      height: 200,
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: IqShadows.lg,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 28,
            top: 36,
            width: 270,
            child: Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: IqText.display.copyWith(color: IqColors.fg),
            ),
          ),
          const Positioned(
            left: 28,
            top: 158,
            width: 270,
            height: 1,
            child: ColoredBox(color: IqColors.line),
          ),
          Positioned(
            left: 28,
            top: 179,
            child: IqPressable(
              onTap: onAction,
              semanticLabel: action,
              builder: (context, pressed) => Text(
                action,
                maxLines: 1,
                softWrap: false,
                style: IqText.button.copyWith(color: IqColors.brand),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
