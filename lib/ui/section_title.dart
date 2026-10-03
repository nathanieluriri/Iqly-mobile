import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

/// Exp/SectionTitle: a section heading with its item count and the "See all"
/// link, shown only when the section is truncated. The root clips its
/// content, so only the top sliver of the brush underline shows, as in Figma.
///
/// Figma over brief: the link is "See all" only; there is no Filter option.
class IqSectionTitle extends StatelessWidget {
  const IqSectionTitle({
    super.key,
    this.title = 'Closing soon',
    this.count = '3',
    this.showCount = true,
    this.showLink = true,
    this.onSeeAll,
  });

  final String title;
  final String count;
  final bool showCount;
  final bool showLink;
  final VoidCallback? onSeeAll;

  static const double linkHitWidth = 72;

  @override
  Widget build(BuildContext context) {
    return _VerticalSlop(
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Figma's 28 pt spacer sits on the title baseline, which lifts the
            // row 8.8 above the title box.
            Padding(
              padding: const EdgeInsets.only(top: 8.8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: IqText.title.copyWith(color: IqColors.brand),
                          ),
                        ),
                        if (showCount) ...[
                          const SizedBox(width: IqSpace.s2),
                          Text(
                            count.toUpperCase(),
                            style: IqText.mono.copyWith(color: IqColors.fg3),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showLink) ...[
                    const SizedBox(width: IqSpace.s2),
                    ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'See all',
                            style: IqText.smallStrong.copyWith(
                              color: IqColors.primary,
                            ),
                          ),
                          const SizedBox(width: IqSpace.s0p5),
                          const IqIcon(
                            IqIcons.forward,
                            size: 16,
                            color: IqColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Positioned(
              left: 0,
              bottom: -3.2,
              width: 75.84,
              height: 4.2,
              child: IqVector(
                'assets/vectors/section-title-underline.svg',
                color: IqColors.accent,
              ),
            ),
            if (showLink)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: linkHitWidth,
                child: IqPressable(
                  onTap: onSeeAll,
                  semanticLabel: 'See all',
                  builder: (context, pressed) => const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lets taps just above or below the box land on its top or bottom edge, so
/// the 33 pt row gives "See all" a 44 pt tall target without changing the
/// layout.
class _VerticalSlop extends SingleChildRenderObjectWidget {
  const _VerticalSlop({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderVerticalSlop();
}

class _RenderVerticalSlop extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final slop = size.height < 44 ? (44 - size.height) / 2 : 0.0;
    if (position.dx < 0 ||
        position.dx > size.width ||
        position.dy < -slop ||
        position.dy > size.height + slop) {
      return false;
    }
    final inside = Offset(
      position.dx,
      position.dy.clamp(0.0, size.height - 0.5),
    );
    if (hitTestChildren(result, position: inside)) {
      result.add(BoxHitTestEntry(this, inside));
      return true;
    }
    return false;
  }
}
