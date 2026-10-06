import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'highlight.dart';
import 'icon.dart';
import 'pressable.dart';
import 'sample_logo.dart';

enum IqNotificationKind { deadline, spots, result, payout }

/// Exp/Notification: a feed row that leads with the number that creates
/// urgency (hours left, spots left, naira won or paid) on a highlighter.
/// Deadline and Spots come from challenge data; Result and Payout mirror
/// ledger and withdrawal rows. The feed is a proposal behind Flags.
/// [headline] defaults to the Figma override for the [kind]; Result and
/// Payout read [resultDetail] and [payoutDetail], as the Figma props do.
/// [highlightDelay] holds the headline's marker wipe for the row's arrive
/// (MOTION-SPEC §7.5); a row that turns read shrinks its dot away, 120 ms
/// ease-in (a cut under reduced motion).
///
/// Figma over brief: adds Divider and the kind-specific detail props.
/// Figma over brief: since the 5 Oct update the mark is a circle, the time
/// is Mob/Small (not mono caps), Spots inks brand, and [showLogo] swaps the
/// glyph for the business logo ([logo]).
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
    this.showLogo = false,
    this.logo = const IqSampleLogo(IqSampleLogoBrand.sunline),
    this.highlightDelay = Duration.zero,
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
  final bool showLogo;
  final Widget logo;
  final Duration highlightDelay;
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
        IqColors.brand,
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
                      shape: BoxShape.circle,
                    ),
                    child: showLogo
                        ? ClipOval(child: SizedBox.expand(child: logo))
                        : IqIcon(icon, size: 22, color: iconInk),
                  ),
                  const SizedBox(width: IqSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IqHighlight(
                          text: headline ?? text,
                          tone: tone,
                          delay: highlightDelay,
                        ),
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
                        when,
                        style: IqText.small.copyWith(color: IqColors.fg2),
                      ),
                      const SizedBox(height: IqSpace.s1p5),
                      AnimatedScale(
                        scale: unread ? 1 : 0,
                        duration: motion(context, IqDurations.press),
                        curve: IqCurves.easeIn,
                        child: Semantics(
                          label: unread ? 'Unread' : null,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: IqColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
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
