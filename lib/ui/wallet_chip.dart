import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Exp/WalletChip: the header wallet entry. Money stays small on Discover;
/// the Wallet tab holds the detail.
///
/// Figma over brief: the Figma sample reads ₦12,500 with no kobo while the
/// money rule gives wallet figures two decimals; [amount] is whatever the
/// caller formats.
class IqWalletChip extends StatelessWidget {
  const IqWalletChip({super.key, this.amount = '₦12,500', this.onTap});

  final String amount;
  final VoidCallback? onTap;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: 'Wallet, $amount',
      haptic: IqHaptics.select,
      builder: (context, pressed) => AnimatedContainer(
        duration: pressed ? IqDurations.dim : IqDurations.release,
        height: height,
        padding: const EdgeInsets.only(left: IqSpace.s3, right: 14),
        decoration: BoxDecoration(
          color: pressed ? IqColors.panel : IqColors.card,
          borderRadius: BorderRadius.circular(IqRadius.full),
          border: Border.all(color: IqColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IqIcon(IqIcons.wallet, size: 18, color: IqColors.brand),
            const SizedBox(width: IqSpace.s2),
            Text(
              amount,
              maxLines: 1,
              style: IqText.smallStrong.copyWith(color: IqColors.fg),
            ),
          ],
        ),
      ),
    );
  }
}
