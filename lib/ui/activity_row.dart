import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Exp/ActivityRow/Award: a ledger credit. Amount with a leading +, in ok
/// green.
class IqActivityRowAward extends StatelessWidget {
  const IqActivityRowAward({
    super.key,
    this.amount = '+₦12,500.00',
    this.when = '2d ago',
    this.divider = true,
    this.onTap,
  });

  final String amount;
  final String when;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _ActivityRow(
      markFill: IqColors.okSoft,
      icon: IqIcons.trophy,
      iconInk: IqColors.ok,
      type: 'award',
      amount: amount,
      amountInk: IqColors.ok,
      divider: divider,
      onTap: onTap,
      meta: Text(when, style: IqText.small.copyWith(color: IqColors.fg3)),
    );
  }
}

/// Figma Badge variants on the status chip.
enum IqActivityRowStatusTone { secondary, standard, destructive }

/// Exp/ActivityRow/Withdrawal: a withdrawal, plain amount, no sign, with the
/// raw [status] word in a chip: completed is Default, failed and reversed
/// are Destructive, anything else (pending, processing) is Secondary.
///
/// Figma over brief: the chip is the web-kit Badge (Label/Badge, Plus
/// Jakarta Sans Medium 12), so the row is 65 tall, one more than Award.
class IqActivityRowWithdrawal extends StatelessWidget {
  const IqActivityRowWithdrawal({
    super.key,
    this.amount = '₦10,000.00',
    this.when = '2h ago',
    this.status = 'pending',
    this.divider = true,
    this.onTap,
  });

  final String amount;
  final String when;
  final String status;
  final bool divider;
  final VoidCallback? onTap;

  static IqActivityRowStatusTone toneOf(String status) => switch (status) {
    'completed' => IqActivityRowStatusTone.standard,
    'failed' || 'reversed' => IqActivityRowStatusTone.destructive,
    _ => IqActivityRowStatusTone.secondary,
  };

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (toneOf(status)) {
      IqActivityRowStatusTone.standard => (
        IqColors.primary,
        IqColors.primaryFg,
      ),
      IqActivityRowStatusTone.destructive => (IqColors.errWash, IqColors.err),
      IqActivityRowStatusTone.secondary => (
        IqColors.secondary,
        IqColors.secondaryFg,
      ),
    };
    return _ActivityRow(
      markFill: IqColors.tintStrong,
      icon: IqIcons.bank,
      iconInk: IqColors.primary,
      type: 'withdrawal',
      amount: amount,
      amountInk: IqColors.fg,
      divider: divider,
      onTap: onTap,
      meta: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(when, style: IqText.small.copyWith(color: IqColors.fg3)),
          const SizedBox(width: IqSpace.s2),
          Container(
            height: 20,
            padding: const EdgeInsets.symmetric(
              horizontal: IqSpace.s2,
              vertical: IqSpace.s0p5,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(IqRadius.md),
            ),
            child: Text(
              status,
              style: IqText.label.copyWith(
                color: ink,
                fontWeight: FontWeight.w500,
                height: 1.33,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.markFill,
    required this.icon,
    required this.iconInk,
    required this.type,
    required this.amount,
    required this.amountInk,
    required this.divider,
    required this.meta,
    this.onTap,
  });

  final Color markFill;
  final IqIcons icon;
  final Color iconInk;
  final String type;
  final String amount;
  final Color amountInk;
  final bool divider;
  final Widget meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      builder: (context, _) => ColoredBox(
        color: IqColors.card,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: IqSpace.s4,
                vertical: IqSpace.s3,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: markFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IqIcon(icon, size: 22, color: iconInk),
                  ),
                  const SizedBox(width: IqSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                type.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: IqText.mono.copyWith(color: IqColors.fg),
                              ),
                            ),
                            const SizedBox(width: IqSpace.s2),
                            Text(
                              amount,
                              style: IqText.figureSmall.copyWith(
                                color: amountInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: IqSpace.s0p5),
                        meta,
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (divider)
              const Positioned(
                left: 68,
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
