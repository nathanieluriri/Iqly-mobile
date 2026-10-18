import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

/// Exp/ReferralCard: the hand-drawn gift, one line of value and the invite
/// code with copy. The card opens Referrals (the screen wraps it); the code
/// copies through [onCopy].
class IqReferralCard extends StatelessWidget {
  const IqReferralCard({
    super.key,
    this.title = 'Invite friends, earn ₦500',
    this.code = 'ADAEZE24',
    this.onCopy,
  });

  final String title;
  final String code;
  final VoidCallback? onCopy;

  static const Size size = Size(358, 76);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
      decoration: BoxDecoration(
        color: IqColors.accentSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 52,
            child: Stack(
              children: [
                Positioned(
                  left: 6,
                  top: 15,
                  child: IqVector(
                    'assets/vectors/referral-card-gift.svg',
                    color: IqColors.accent,
                    width: 40,
                    height: 33,
                  ),
                ),
                Positioned(
                  left: 10.5,
                  top: 5.29,
                  child: IqVector(
                    'assets/vectors/referral-card-ribbon.svg',
                    color: IqColors.brand,
                    width: 31,
                    height: 45,
                  ),
                ),
                Positioned(
                  left: 40.3,
                  top: 2.8,
                  child: IqVector(
                    'assets/vectors/referral-card-twinkle.svg',
                    color: IqColors.accentStrong,
                    width: 10,
                    height: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                ),
                const SizedBox(height: IqSpace.s1),
                IqPressable(
                  onTap: onCopy,
                  semanticLabel: 'Copy code $code',
                  hint: 'Copy code $code',
                  haptic: null,
                  builder: (context, pressed) => PressDim(
                    pressed: pressed,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              code.toUpperCase(),
                              maxLines: 1,
                              softWrap: false,
                              style: IqText.mono.copyWith(color: IqColors.fg2),
                            ),
                          ),
                        ),
                        const SizedBox(width: IqSpace.s1p5),
                        const IqIcon(
                          IqIcons.copy,
                          size: 16,
                          color: IqColors.brand,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const IqIcon(IqIcons.forward, size: 24, color: IqColors.brand),
        ],
      ),
    );
  }
}
