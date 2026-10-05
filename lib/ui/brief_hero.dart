import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'sample_cover.dart';
import 'sample_logo.dart';

/// Exp/BriefHero: the brief detail hero, the business's own visual (a
/// product shot or an ad). [assets] dots show when there is more than one
/// to swipe; [current] is the lit one. Back and bookmark float on it from
/// the screen. The logo hangs 28 below the photo, so leave room under it.
class IqBriefHero extends StatelessWidget {
  const IqBriefHero({
    super.key,
    this.cover = const IqSampleCover(IqSampleLogoBrand.orchidFoods),
    this.logo = const IqSampleLogo(IqSampleLogoBrand.sunline),
    this.showDots = true,
    this.showLogo = true,
    this.assets = 3,
    this.current = 0,
    this.height = defaultHeight,
  });

  final Widget cover;
  final Widget logo;
  final bool showDots;
  final bool showLogo;
  final int assets;
  final int current;

  /// Screens resize the instance (Submission detail 35:146 sets 160); the
  /// logo keeps its 28 overhang.
  final double height;

  static const double defaultHeight = 280;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: IqColors.line2,
              child: ClipRect(child: cover),
            ),
          ),
          if (showDots && assets > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: Container(
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: IqSpace.s2),
                  decoration: BoxDecoration(
                    color: IqColors.fg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < assets; i++) ...[
                        if (i > 0) const SizedBox(width: IqSpace.s1p5),
                        _Dot(lit: i == current),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (showLogo)
            Positioned(
              left: IqSpace.s4,
              top: height - 28,
              child: Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(IqSpace.s1),
                decoration: const BoxDecoration(
                  color: IqColors.card,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(child: SizedBox.expand(child: logo)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lit ? 16 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: lit
            ? IqColors.primaryFg
            : IqColors.primaryFg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
