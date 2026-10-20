import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../data/models.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/pressable.dart';
import '../discover/business_art.dart';
import '../discover/discover_widgets.dart' show businessLabel;

/// The cover header's measures at one width (1713:34569): the 200 photo,
/// then the business beside the logo and the ask in up to two lines,
/// 12 above, 6 apart and 16 below.
class CoverMetrics {
  const CoverMetrics._({required this.business, required this.title});

  factory CoverMetrics.of(BuildContext context, Brief brief, double width) {
    double measure(String text, TextStyle style, int lines) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: lines,
        ellipsis: '…',
      )..layout(maxWidth: math.max(0, width - 2 * IqSpace.s4));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    return CoverMetrics._(
      business: measure(businessLabel(brief), IqText.smallStrong, 1),
      title: measure(brief.title, IqText.title, titleLines),
    );
  }

  static const double photo = 200;
  static const double logo = 56;
  static const double overhang = 28;
  static const double bar = 56;
  static const int titleLines = 2;

  final double business;
  final double title;

  double get businessTop => photo + IqSpace.s3;
  double get titleTop => businessTop + business + IqSpace.s1p5;
  double get expanded => titleTop + title + IqSpace.s4;

  /// How far the page scrolls before the header is the bar.
  double get range => expanded - bar;
}

/// Exp/CoverHeader (proposal, 1713:34569) as a pinned sliver: Expanded, the
/// brief's photo full width with Back and More on it, the logo hanging off
/// its edge, the business and the ask under it; scrolled, the photo slides
/// away at half speed and fades, the ask goes under, and it settles as the
/// 56 Collapsed bar: Back, the business over the ask, More.
class CoverHeader extends SliverPersistentHeaderDelegate {
  const CoverHeader({
    required this.brief,
    required this.metrics,
    required this.onBack,
    required this.onMore,
  });

  final Brief brief;
  final CoverMetrics metrics;
  final VoidCallback onBack;
  final VoidCallback onMore;

  @override
  double get maxExtent => metrics.expanded;

  @override
  double get minExtent => CoverMetrics.bar;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    const photo = CoverMetrics.photo;
    final m = metrics;
    final s = math.min(shrinkOffset, m.range);
    final t = m.range <= 0 ? 1.0 : s / m.range;
    double span(double from, double to) =>
        IqCurves.easeOut.transform(((s - from) / (to - from)).clamp(0.0, 1.0));
    final shown = math.max(0.0, photo - s);
    final buttonTop = IqSpace.s3 - IqSpace.s1p5 * t;
    return SizedBox.expand(
      child: ColoredBox(
        color: IqColors.bg,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: shown,
                child: ClipRect(
                  child: Opacity(
                    opacity: 1 - span(0, photo),
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: photo,
                      maxHeight: photo,
                      child: Transform.translate(
                        offset: Offset(0, -s / 2),
                        child: ColoredBox(
                          color: IqColors.line2,
                          child: SizedBox.expand(
                            child: businessCover(brief.cover),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: IqSpace.s4,
                top: photo - CoverMetrics.overhang - s,
                child: Opacity(
                  opacity: 1 - span(photo - 120, photo - 40),
                  child: Container(
                    width: CoverMetrics.logo,
                    height: CoverMetrics.logo,
                    padding: const EdgeInsets.all(IqSpace.s1),
                    decoration: const BoxDecoration(
                      color: IqColors.card,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: SizedBox.expand(child: businessLogo(brief.logo)),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: IqSpace.s4,
                right: IqSpace.s4,
                top: m.businessTop - s,
                child: Opacity(
                  opacity: 1 - span(m.range * .45, m.range * .85),
                  child: ExcludeSemantics(
                    excluding: t >= 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 66),
                          child: Text(
                            businessLabel(brief),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: IqText.smallStrong.copyWith(
                              color: IqColors.fg2,
                            ),
                          ),
                        ),
                        const SizedBox(height: IqSpace.s1p5),
                        Text(
                          brief.title,
                          maxLines: CoverMetrics.titleLines,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.title.copyWith(color: IqColors.fg),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: IqSpace.s4 + RoundIconButton.size + IqSpace.s3,
                right: IqSpace.s4 + RoundIconButton.size + IqSpace.s3,
                top: 0,
                height: CoverMetrics.bar,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: span(m.range * .8, m.range),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessLabel(brief),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.small.copyWith(color: IqColors.fg2),
                        ),
                        Text(
                          brief.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: IqSpace.s4,
                top: buttonTop,
                child: RoundIconButton(
                  icon: IqIcons.back,
                  label: 'Back',
                  color: IqColors.brand,
                  onTap: onBack,
                ),
              ),
              Positioned(
                right: IqSpace.s4,
                top: buttonTop,
                child: RoundIconButton.more(onTap: onMore),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(CoverHeader old) =>
      old.brief != brief ||
      old.metrics.title != metrics.title ||
      old.metrics.business != metrics.business ||
      old.onBack != onBack ||
      old.onMore != onMore;
}

/// Exp/RoundIconButton (proposal, 1713:34487): a 24 icon on a 44 white
/// circle, legible on the photo and on the page. Pressed fills panel.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required IqIcons this.icon,
    required this.label,
    this.color = IqColors.fg,
    this.onTap,
  });

  /// More, the vertical three dots (611:265). The set has no such icon and
  /// a Dart-only patch ships no new SVG, so the dots are drawn here.
  const RoundIconButton.more({super.key, this.onTap})
    : icon = null,
      label = 'More',
      color = IqColors.fg;

  final IqIcons? icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: label,
      hint: label,
      builder: (context, pressed) => AnimatedContainer(
        width: size,
        height: size,
        alignment: Alignment.center,
        duration: pressed ? IqDurations.dim : IqDurations.release,
        curve: IqCurves.easeOut,
        decoration: BoxDecoration(
          color: pressed ? IqColors.panel : IqColors.card,
          shape: BoxShape.circle,
        ),
        child: switch (icon) {
          final icon? => IqIcon(icon, size: 24, color: color),
          null => _Dots(color: color),
        },
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.color});

  final Color color;

  static const double _dot = 4;

  @override
  Widget build(BuildContext context) {
    final dot = DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: _dot),
    );
    return SizedBox.square(
      dimension: 24,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          dot,
          const SizedBox(height: 3),
          dot,
          const SizedBox(height: 3),
          dot,
        ],
      ),
    );
  }
}

enum SubmitGuideState { progress, ready, error }

/// Exp/SubmitGuide (proposal, 1713:34506): one 40 line under the cover
/// with a hairline under it. Progress counts what is left in fg2; Ready
/// takes the check and the words in fg; Error, only once Continue was
/// pressed, the cross and the words in err. The step sits at the end.
class SubmitGuide extends StatelessWidget {
  const SubmitGuide({
    super.key,
    required this.words,
    required this.step,
    this.state = SubmitGuideState.progress,
  });

  final String words;
  final String step;
  final SubmitGuideState state;

  static const double height = 40;
  static const double _icon = 18;

  /// The line at the reader's text size, never under 40.
  static double extentOf(BuildContext context) {
    final painter = TextPainter(
      text: const TextSpan(text: 'Step', style: IqText.smallStrong),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final extent = math.max(height, painter.height + 2 * IqSpace.s2p5 + 1);
    painter.dispose();
    return extent;
  }

  @override
  Widget build(BuildContext context) {
    final (icon, style) = switch (state) {
      SubmitGuideState.progress => (
        null,
        IqText.small.copyWith(color: IqColors.fg2),
      ),
      SubmitGuideState.ready => (
        IqIcons.success,
        IqText.smallStrong.copyWith(color: IqColors.fg),
      ),
      SubmitGuideState.error => (
        IqIcons.error,
        IqText.smallStrong.copyWith(color: IqColors.err),
      ),
    };
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: IqColors.bg,
        border: Border(bottom: BorderSide(color: IqColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
        child: Row(
          children: [
            if (icon != null) ...[
              IqIcon(
                icon,
                key: ValueKey(icon),
                size: _icon,
                color: IqColors.brand,
              ),
              const SizedBox(width: IqSpace.s2),
            ],
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: RollingText(
                  words,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
            const SizedBox(width: IqSpace.s2),
            Text(step, style: IqText.small.copyWith(color: IqColors.fg2)),
          ],
        ),
      ),
    );
  }
}

/// [SubmitGuide] pinned under the cover header.
class GuideHeader extends SliverPersistentHeaderDelegate {
  const GuideHeader({required this.guide, required this.extent});

  final SubmitGuide guide;
  final double extent;

  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: guide);

  @override
  bool shouldRebuild(GuideHeader old) =>
      old.extent != extent ||
      old.guide.words != guide.words ||
      old.guide.step != guide.step ||
      old.guide.state != guide.state;
}
