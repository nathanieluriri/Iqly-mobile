import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'illustration.dart';
import 'pressable.dart';
import 'vector.dart';

/// Exp/ReferralCard: the referral coupon. A lilac main with the offer, a
/// dashed code pill with copy and the joined count; a torn edge into the
/// orange stub with the Gift figure and Invite.
///
/// Figma marks it a proposal: the programme and the ₦500 are not in the
/// product yet, so screens keep it behind a flag.
class IqReferralCard extends StatelessWidget {
  const IqReferralCard({
    super.key,
    this.eyebrow = 'Invite a friend',
    this.title = '₦500 each when your friend wins a first brief.',
    this.code = 'ADAEZE24',
    this.joined = '3 joined',
    this.stubLabel = 'Invite',
    this.onCopy,
    this.onInvite,
  });

  final String eyebrow;
  final String title;
  final String code;
  final String joined;
  final String stubLabel;
  final VoidCallback? onCopy;
  final VoidCallback? onInvite;

  static const Size size = Size(358, 140);
  static const double main = 240;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: main,
              child: Container(
                color: IqColors.tint,
                padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: IqText.mono.copyWith(color: IqColors.brand),
                    ),
                    const SizedBox(height: IqSpace.s1p5),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.cardTitle.copyWith(color: IqColors.fg),
                    ),
                    const SizedBox(height: IqSpace.s1p5),
                    Padding(
                      padding: const EdgeInsets.only(top: IqSpace.s1),
                      child: Row(
                        children: [
                          IqPressable(
                            onTap: onCopy,
                            semanticLabel: 'Copy code $code',
                            haptic: IqHaptics.select,
                            builder: (context, pressed) => PressDim(
                              pressed: pressed,
                              child: _CodePill(code: code),
                            ),
                          ),
                          const SizedBox(width: IqSpace.s2),
                          Text(
                            joined,
                            style: IqText.small.copyWith(color: IqColors.fg2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: main,
              top: 0,
              right: 0,
              bottom: 0,
              child: IqPressable(
                onTap: onInvite,
                semanticLabel: stubLabel,
                builder: (context, pressed) => ColoredBox(
                  color: pressed ? IqColors.accentStrong : IqColors.accent,
                  child: Stack(
                    children: [
                      const Positioned(
                        left: 6,
                        top: 3,
                        width: 96,
                        height: 102,
                        child: IqFigure(IqFigures.gift, width: 96),
                      ),
                      Positioned(
                        left: 33,
                        top: 108,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stubLabel,
                              style: IqText.smallStrong.copyWith(
                                color: IqColors.primaryFg,
                              ),
                            ),
                            const SizedBox(width: IqSpace.s1),
                            const IqIcon(
                              IqIcons.forward,
                              size: 14,
                              color: IqColors.primaryFg,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: main,
              top: 0,
              width: 13,
              height: 140,
              child: IqVector(
                'assets/vectors/referral-card-torn-edge.svg',
                color: IqColors.tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodePill extends StatelessWidget {
  const _CodePill({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPill(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s2p5,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: IqColors.card,
          borderRadius: BorderRadius.circular(IqRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code.toUpperCase(),
              style: IqText.mono.copyWith(color: IqColors.fg),
            ),
            const SizedBox(width: IqSpace.s1p5),
            const IqIcon(IqIcons.copy, size: 14, color: IqColors.brand),
          ],
        ),
      ),
    );
  }
}

/// Figma's 1.5 inside stroke with a 3, 3 dash around the code pill: plain
/// geometry, not a brush shape.
class _DashedPill extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(IqRadius.md)),
      );
    final paint = Paint()
      ..color = IqColors.fg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPill old) => false;
}
