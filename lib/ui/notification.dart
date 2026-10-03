import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'highlight.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqNotificationKind { deadline, spots, result, payout }

/// Exp/Notification: a feed row that leads with the number that creates
/// urgency (hours left, spots left, naira won or paid) on a highlighter.
/// Deadline and Spots come from challenge data; Result and Payout mirror
/// ledger and withdrawal rows. The feed is a proposal behind Flags.
/// [headline] defaults to the Figma override for the [kind]; Result and
/// Payout read [resultDetail] and [payoutDetail], as the Figma props do.
///
/// Figma over brief: adds Divider and the kind-specific detail props.
class IqNotification extends StatelessWidget {
  const IqNotification({
    super.key,
    this.kind = IqNotificationKind.deadline,
    this.headline,
    this.detail = 'Sunline · A tagline for a solar kiosk network',
    this.resultDetail = 'Why do Lagosians skip mobile banking on Sundays?',
    this.payoutDetail = 'Sent to Access Bank ••6789 · completed',
    this.when = '2h',
    this.unread = true,
    this.divider = true,
    this.onTap,
  });

  final IqNotificationKind kind;
  final String? headline;
  final String detail;
  final String resultDetail;
  final String payoutDetail;
  final String when;
  final bool unread;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (markFill, icon, iconInk, tone, text, body) = switch (kind) {
      IqNotificationKind.deadline => (
        IqColors.accentSoft,
        IqIcons.clock,
        IqColors.accentStrong,
        IqHighlightTone.orange,
        'Closes in 6h',
        detail,
      ),
      IqNotificationKind.spots => (
        IqColors.tintStrong,
        IqIcons.polls,
        IqColors.primary,
        IqHighlightTone.lilac,
        '12 spots left',
        detail,
      ),
      IqNotificationKind.result => (
        IqColors.okSoft,
        IqIcons.trophy,
        IqColors.ok,
        IqHighlightTone.green,
        'You won ₦12,500.00',
        resultDetail,
      ),
      IqNotificationKind.payout => (
        IqColors.tintStrong,
        IqIcons.wallet,
        IqColors.brand,
        IqHighlightTone.lilac,
        '₦40,000.00 paid out',
        payoutDetail,
      ),
    };
    return IqPressable(
      onTap: onTap,
      semanticLabel: headline ?? text,
      builder: (context, _) => ColoredBox(
        color: IqColors.card,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: IqSpace.s4,
                vertical: 14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        IqHighlight(text: headline ?? text, tone: tone),
                        const SizedBox(height: IqSpace.s1),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.small.copyWith(color: IqColors.fg2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: IqSpace.s3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        when.toUpperCase(),
                        style: IqText.mono.copyWith(color: IqColors.fg2),
                      ),
                      if (unread) ...[
                        const SizedBox(height: IqSpace.s1p5),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: IqColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
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
