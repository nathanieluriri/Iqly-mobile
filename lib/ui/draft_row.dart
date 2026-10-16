import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'sample_logo.dart';

/// Figma Mode=Default is [IqDraftRowMode.standard].
enum IqDraftRowMode { standard, selecting }

/// Exp/DraftRow: one saved draft in Drafts. The business logo, your title,
/// the brief, step and last edit, and a three-segment bar for the three
/// steps (step 1 is always done). Default ends in a chevron; Selecting
/// swaps it for a checkbox, and a selected row turns tint with a brand
/// outline.
///
/// Figma's Selected axis (False, True) is the [selected] flag; it only
/// shows in Selecting, the only mode Figma draws it in. Tap and long press
/// are the screen's: designer answer rev 55 opens selecting on long press.
/// Selection crossfades in 200 ms, a cut under reduced motion.
///
/// Figma's check instance is sized 14 but its ink keeps the 24 geometry,
/// so the drawn tick is the full 24 icon; the widget follows the drawing.
class IqDraftRow extends StatelessWidget {
  const IqDraftRow({
    super.key,
    this.title = 'No light? We dey',
    this.meta = 'Unibooks · Step 2 of 3 · 2 hours ago',
    this.step2Done = true,
    this.step3Done = false,
    this.logo = const IqSampleLogo(IqSampleLogoBrand.sunline),
    this.mode = IqDraftRowMode.standard,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String meta;
  final bool step2Done;
  final bool step3Done;
  final Widget logo;
  final IqDraftRowMode mode;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const double radius = 16;
  static const double logoSize = 40;

  @override
  Widget build(BuildContext context) {
    final selecting = mode == IqDraftRowMode.selecting;
    final on = selecting && selected;
    final swap = motion(context, IqDurations.swap);
    return GestureDetector(
      onLongPress: onLongPress,
      child: IqPressable(
        onTap: onTap,
        haptic: selecting ? IqHaptics.select : IqHaptics.tap,
        semanticLabel:
            '$title, $meta${selecting ? (on ? ', selected' : ', not selected') : ''}',
        builder: (context, pressed) => AnimatedContainer(
          duration: pressed ? IqDurations.dim : swap,
          curve: IqCurves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: on
                ? IqColors.tint
                : pressed
                ? IqColors.panel
                : IqColors.card,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: on ? IqColors.brand : IqColors.line),
          ),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox.square(dimension: logoSize, child: logo),
              ),
              const SizedBox(width: IqSpace.s3),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.bodyStrong.copyWith(color: IqColors.fg),
                    ),
                    const SizedBox(height: IqSpace.s1p5),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.small.copyWith(color: IqColors.fg2),
                    ),
                    const SizedBox(height: IqSpace.s1p5),
                    _Progress(done: [true, step2Done, step3Done]),
                  ],
                ),
              ),
              const SizedBox(width: IqSpace.s3),
              AnimatedSwitcher(
                duration: swap,
                child: selecting
                    ? _Checkbox(key: const ValueKey('check'), on: on)
                    : const IqIcon(
                        IqIcons.forward,
                        key: ValueKey('chevron'),
                        color: IqColors.fg3,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma draws three 70 pt segments 4 apart; each done fill runs 9 past its
/// segment, bridging the gap, and the next segment paints over the rest. A
/// fill that continues a done step is square on the left so no seam shows.
class _Progress extends StatelessWidget {
  const _Progress({required this.done});

  final List<bool> done;

  static const double segment = 70;
  static const double overrun = 9;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(2);
    return SizedBox(
      height: IqSpace.s1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < done.length; i++) ...[
            if (i > 0) const SizedBox(width: IqSpace.s1),
            SizedBox(
              width: segment,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: IqColors.line,
                      borderRadius: shape,
                    ),
                  ),
                  if (done[i])
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      right: -overrun,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: IqColors.brand,
                          borderRadius: i > 0 && done[i - 1]
                              ? const BorderRadius.horizontal(
                                  right: Radius.circular(2),
                                )
                              : shape,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: motion(context, IqDurations.swap),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? IqColors.brand : IqColors.card.withValues(alpha: 0),
        border: on ? null : Border.all(color: IqColors.line, width: 1.5),
      ),
      child: on ? const IqIcon(IqIcons.check, color: IqColors.primaryFg) : null,
    );
  }
}
