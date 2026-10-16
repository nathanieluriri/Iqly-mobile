import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'cover_with_logo.dart';
import 'icon.dart';
import 'pressable.dart';
import 'sample_cover.dart';
import 'sample_logo.dart';

/// Exp/ContinueCard: shown at the top of Discover only when a draft
/// exists. The bar fill is the share of the answer written ([progress],
/// 0 to 1); the card opens the restored draft.
class IqContinueCard extends StatelessWidget {
  const IqContinueCard({
    super.key,
    this.title = 'Naming a new sparkling water brand for Gen Z.',
    this.status = 'Draft saved · 2h ago',
    this.progress = 0.45,
    this.cover = const IqSampleCover(IqSampleLogoBrand.orchidFoods),
    this.logo = const IqSampleLogo(IqSampleLogoBrand.orchidFoods),
    this.onTap,
  });

  final String title;
  final String status;
  final double progress;
  final Widget cover;
  final Widget logo;
  final VoidCallback? onTap;

  static const double height = 80;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IqPressable(
      tactile: false,
      onTap: onTap,
      semanticLabel: '$title. $status',
      builder: (context, pressed) => AnimatedScale(
        scale: pressed && !reduced ? IqScale.cardPress : 1,
        duration: pressMotion(context, pressed),
        curve: IqCurves.easeOut,
        child: Container(
          height: height,
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s2p5,
            IqSpace.s2p5,
            IqSpace.s3,
            IqSpace.s3,
          ),
          decoration: BoxDecoration(
            color: IqColors.tint,
            borderRadius: BorderRadius.circular(IqRadius.xl2),
          ),
          child: Row(
            children: [
              CoverWithLogo(
                size: const Size.square(60),
                radius: IqRadius.xl,
                cover: cover,
                logo: logo,
                logoOffset: const Offset(42, 42),
                logoSize: 24,
                logoInset: 2,
              ),
              const SizedBox(width: IqSpace.s3),
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
                    const SizedBox(height: IqSpace.s1p5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: ColoredBox(color: IqColors.line),
                            ),
                            FractionallySizedBox(
                              widthFactor: progress.clamp(0, 1),
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: IqColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: IqSpace.s1p5),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.small.copyWith(color: IqColors.fg2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: IqSpace.s3),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: IqColors.brand,
                  shape: BoxShape.circle,
                ),
                child: const IqIcon(
                  IqIcons.forward,
                  size: 20,
                  color: IqColors.primaryFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
