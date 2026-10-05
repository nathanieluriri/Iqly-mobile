import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'meta.dart';
import 'pressable.dart';
import 'sample_logo.dart';

enum IqWalletRowKind { award, withdrawal }

/// The withdrawal states, exactly as the product words them.
enum IqWalletRowStatus {
  pending('Pending', IqMetaKind.time),
  completed('Completed', IqMetaKind.done),
  failed('Failed · nothing left your wallet', IqMetaKind.failed),
  reversed('Reversed · back in your wallet', IqMetaKind.plain);

  const IqWalletRowStatus(this.label, this.meta);

  final String label;
  final IqMetaKind meta;
}

/// Exp/WalletRow: an activity row. Rewards lead with the business logo and
/// the brief; withdrawals lead with the bank and a status chip.
///
/// The logo is not clipped: each mark carries its own shape, as in Figma
/// (sample logos are round, the referral logomark tile is a rounded square).
///
/// Figma over brief: the kit draws Pending, Completed and Failed only. The
/// designer made Failed and Reversed distinct states (answer 7); Reversed
/// has no Figma chip yet, so it uses the plain Meta chip until one lands.
/// A failed amount is struck through in fg3 (Figma Status=Failed); Reversed
/// follows it, as nothing left the wallet either.
class IqWalletRow extends StatelessWidget {
  const IqWalletRow({
    super.key,
    this.kind = IqWalletRowKind.award,
    this.title = 'Volt Riders',
    this.detail = 'Reward · Name our electric okada fleet',
    this.amount = '+₦50,000.00',
    this.when = '13 days ago',
    this.status = IqWalletRowStatus.pending,
    this.logo = const IqSampleLogo(IqSampleLogoBrand.voltRiders, size: 40),
    this.divider = true,
    this.onTap,
  });

  final IqWalletRowKind kind;
  final String title;
  final String detail;
  final String amount;
  final String when;
  final IqWalletRowStatus status;
  final Widget logo;
  final bool divider;
  final VoidCallback? onTap;

  static const double height = 64;

  @override
  Widget build(BuildContext context) {
    final award = kind == IqWalletRowKind.award;
    final returned =
        !award &&
        (status == IqWalletRowStatus.failed ||
            status == IqWalletRowStatus.reversed);
    return IqPressable(
      onTap: onTap,
      semanticLabel: award
          ? '$title, $detail, $amount, $when'
          : '$title, ${status.label}, $amount, $when',
      builder: (context, pressed) => AnimatedContainer(
        duration: pressed ? IqDurations.dim : IqDurations.release,
        height: height,
        color: pressed ? IqColors.panel : IqColors.bg.withValues(alpha: 0),
        child: Stack(
          children: [
            Padding(
              // Figma pads 12 top and bottom yet centres a 47 tall body in
              // the 64 row, so the body may use the padding.
              padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
              child: Row(
                children: [
                  if (award)
                    SizedBox.square(dimension: 40, child: logo)
                  else
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: IqColors.tint,
                        shape: BoxShape.circle,
                      ),
                      child: const IqIcon(
                        IqIcons.bank,
                        size: 20,
                        color: IqColors.brand,
                      ),
                    ),
                  const SizedBox(width: IqSpace.s3),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                        ),
                        const SizedBox(height: IqSpace.s1),
                        if (award)
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: IqText.small.copyWith(color: IqColors.fg2),
                          )
                        else
                          IqMeta(kind: status.meta, label: status.label),
                      ],
                    ),
                  ),
                  const SizedBox(width: IqSpace.s3),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount,
                        maxLines: 1,
                        style: IqText.bodyStrong.copyWith(
                          color: award
                              ? IqColors.ok
                              : returned
                              ? IqColors.fg3
                              : IqColors.fg,
                          decoration: returned
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: IqColors.fg3,
                        ),
                      ),
                      const SizedBox(height: IqSpace.s1),
                      Text(
                        when,
                        maxLines: 1,
                        style: IqText.small.copyWith(color: IqColors.fg3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (divider)
              const Positioned(
                left: 72,
                right: 0,
                bottom: 0,
                height: 1,
                child: ColoredBox(color: IqColors.line),
              ),
          ],
        ),
      ),
    );
  }
}
