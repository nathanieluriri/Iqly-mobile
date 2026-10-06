import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'pressable.dart';

/// Exp/TipCard: the first-run tip over a dimmed screen, one headline, a
/// hairline and one text action (the only tap target). The scrim belongs
/// to the screen.
///
/// Figma over brief: the component default action is "Ok, got it"; the screen overrides it to "OK, got it", used here.
/// Figma fixes the card at 200 tall, which its own padding (36 top, 28
/// bottom, 20 gaps) cannot hold, so the action overhangs the bottom; here
/// the card hugs its content, keeping every Figma gap, and the action sits
/// in a 44 pt band (its text still 20 under the hairline and 28 over the
/// edge).
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

  static const double width = 326;

  /// The action band and how far it reaches past the text above and below.
  static const double _band = 44;
  static const double _bandReach = (_band - 18) / 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: IqShadows.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 0),
            child: Text(
              title,
              style: IqText.display.copyWith(color: IqColors.fg),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: SizedBox(
              height: 1,
              width: double.infinity,
              child: ColoredBox(color: IqColors.line),
            ),
          ),
          const SizedBox(height: 20 - _bandReach),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: IqPressable(
              onTap: onAction,
              semanticLabel: action,
              builder: (context, pressed) => SizedBox(
                height: _band,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Text(
                      action,
                      maxLines: 1,
                      softWrap: false,
                      style: IqText.button.copyWith(color: IqColors.brand),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28 - _bandReach),
        ],
      ),
    );
  }
}
