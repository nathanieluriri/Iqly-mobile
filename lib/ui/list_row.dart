import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Figma Tone=Default is [standard]; Danger is for destructive rows only
/// (Sign out, Remove bank).
enum IqListRowTone { standard, danger }

/// Exp/ListRow: the settings and profile row, an icon tile, label, optional
/// description and chevron. [icon] is the Figma Icon swap; it defaults to
/// profile, and to close on Danger rows.
///
/// Pressing fills the row panel (100 ms, back in 160; spec 5.24, build
/// extension), the same under reduced motion.
///
/// Figma over brief: a Danger tone exists (red tile and label, no chevron).
/// Figma over brief: the Icon prop is an instance swap.
/// Figma over its description: rows are 64 tall, not 56.
/// Figma over brief: the tile glyph is brand ink, not primary.
class IqListRow extends StatelessWidget {
  const IqListRow({
    super.key,
    this.label = 'Your details',
    this.description = 'Phone, location, interests',
    this.showDescription = true,
    this.divider = true,
    this.showChevron = true,
    this.icon,
    this.tone = IqListRowTone.standard,
    this.descriptionMaxLines = 2,
    this.onTap,
  });

  final String label;
  final String description;
  final bool showDescription;
  final bool divider;

  /// The chevron is a hidden nested layer in Figma (B11 Welcome), not a prop.
  final bool showChevron;
  final IqIcons? icon;
  final IqListRowTone tone;

  /// Not a Figma prop: Result · Not selected truncates its Your submission
  /// row to one line (designer doc rev 57).
  final int descriptionMaxLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final danger = tone == IqListRowTone.danger;
    return IqPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, pressed) => AnimatedContainer(
        duration: pressed ? IqDurations.dim : IqDurations.release,
        curve: IqCurves.easeOut,
        color: pressed ? IqColors.panel : IqColors.card,
        constraints: const BoxConstraints(minHeight: 60),
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
                      color: danger ? IqColors.errSoft : IqColors.tintStrong,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IqIcon(
                      icon ?? (danger ? IqIcons.close : IqIcons.profile),
                      size: 22,
                      color: danger ? IqColors.err : IqColors.brand,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.bodyStrong.copyWith(
                            color: danger ? IqColors.err : IqColors.fg,
                          ),
                        ),
                        if (showDescription && !danger) ...[
                          const SizedBox(height: 1),
                          Text(
                            description,
                            maxLines: descriptionMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: IqText.small.copyWith(color: IqColors.fg3),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!danger && showChevron) ...[
                    const SizedBox(width: 14),
                    const IqIcon(
                      IqIcons.forward,
                      size: 18,
                      color: IqColors.fg3,
                    ),
                  ],
                ],
              ),
            ),
            if (divider)
              const Positioned(
                left: 70,
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
