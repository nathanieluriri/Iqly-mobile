import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../core/navigation.dart';
import '../../data/assessment_data.dart';
import '../../data/assessment_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/brand_logo.dart';
import '../../ui/cover_with_logo.dart';
import '../../ui/illustration.dart';
import '../../ui/pressable.dart';

/// Discover card in the Quick polls shape: writer figure, iQLY mark, short
/// title. Folds away after a pass.
class AssessmentNudge extends ConsumerWidget {
  const AssessmentNudge({super.key, this.gap = 0});

  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = assessmentNudge(ref.watch(assessmentAccessProvider).value);
    return Collapse(
      open: copy != null,
      child: Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: IqPressable(
          onTap: () => context.open(Routes.assessment),
          semanticLabel: copy?.label ?? assessmentIntro.title,
          builder: (context, pressed) => AnimatedScale(
            scale: pressed ? IqScale.cardPress : 1,
            duration: pressMotion(context, pressed),
            curve: IqCurves.easeOut,
            child: LineCard(
              inset: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  IqSpace.s3,
                  IqSpace.s3,
                  IqSpace.s2p5,
                  IqSpace.s3,
                ),
                child: Row(
                  children: [
                    CoverWithLogo(
                      size: const Size.square(72),
                      radius: IqRadius.xl,
                      cover: const ColoredBox(
                        color: IqColors.tintStrong,
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: IqFigure(
                              IqFigures.writer,
                              width: IqFigure.designWidth,
                            ),
                          ),
                        ),
                      ),
                      logo: const IqBrandLogo(
                        mark: IqBrandMark.logomark,
                        width: 24,
                        height: 24,
                      ),
                      logoOffset: const Offset(50, 50),
                      logoSize: 28,
                      logoInset: 2,
                    ),
                    const SizedBox(width: IqSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy?.label ?? assessmentIntro.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: IqText.bodyStrong.copyWith(
                              color: IqColors.fg,
                            ),
                          ),
                          const SizedBox(height: IqSpace.s1),
                          Text(
                            copy?.description ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: IqText.small.copyWith(color: IqColors.fg2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
