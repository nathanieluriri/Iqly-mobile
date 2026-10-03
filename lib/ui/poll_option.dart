import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

enum IqPollOptionState { standard, selected, result, chosen }

/// Exp/PollOption: one answer on a poll. Before voting it is a brush outline
/// pill ([onTap] picks it); Selected is filled ink with a check. Result and
/// Chosen show the share bar, whose fill stops at [share] (0 to 1) with the
/// Figma 2.4 point soft edge, and the rounded percentage. Figma
/// State=Default is [IqPollOptionState.standard].
class IqPollOption extends StatelessWidget {
  const IqPollOption({
    super.key,
    this.label = 'Zobo and ginger',
    this.state = IqPollOptionState.standard,
    this.share = 0.45,
    this.onTap,
    this.width = 326,
  });

  final String label;
  final IqPollOptionState state;
  final double share;
  final VoidCallback? onTap;

  /// 326 in the master; Exp/PollCard fills its 324 column.
  final double width;
  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final voting =
        state == IqPollOptionState.standard ||
        state == IqPollOptionState.selected;
    return IqPressable(
      onTap: voting ? onTap : null,
      builder: (context, _) => SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            ..._ground(),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    if (state == IqPollOptionState.selected ||
                        state == IqPollOptionState.chosen) ...[
                      IqIcon(
                        IqIcons.check,
                        size: 18,
                        color: state == IqPollOptionState.selected
                            ? IqColors.primaryFg
                            : IqColors.brand,
                      ),
                      const SizedBox(width: IqSpace.s2p5),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: switch (state) {
                          IqPollOptionState.standard ||
                          IqPollOptionState.result => IqText.body.copyWith(
                            color: IqColors.fg,
                          ),
                          IqPollOptionState.selected =>
                            IqText.bodyStrong.copyWith(
                              color: IqColors.primaryFg,
                            ),
                          IqPollOptionState.chosen =>
                            IqText.bodyStrong.copyWith(color: IqColors.fg),
                        },
                      ),
                    ),
                    if (!voting) ...[
                      const SizedBox(width: IqSpace.s2p5),
                      Text(
                        '${(share * 100).round()}%',
                        style: IqText.figureSmall.copyWith(
                          color: state == IqPollOptionState.chosen
                              ? IqColors.brand
                              : IqColors.fg2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _ground() {
    switch (state) {
      case IqPollOptionState.standard:
        return [
          _outline('assets/vectors/poll-option-outline.svg', IqColors.brand),
        ];
      case IqPollOptionState.selected:
        return [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: IqColors.brand,
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
        ];
      case IqPollOptionState.result:
        return [
          _share(IqColors.panel),
          Positioned(
            left: 0,
            top: 0,
            width: 324.02,
            height: 51.26,
            child: IqVector(
              'assets/vectors/poll-option-outline-result.svg',
              color: IqColors.line2,
            ),
          ),
        ];
      case IqPollOptionState.chosen:
        return [
          _share(IqColors.accentSoft),
          _outline('assets/vectors/poll-option-outline.svg', IqColors.brand),
        ];
    }
  }

  Widget _outline(String asset, Color color) => Positioned(
    left: 0,
    top: 0,
    width: 324.32,
    height: 51.82,
    child: IqVector(asset, color: color),
  );

  Widget _share(Color color) {
    final s = share.clamp(0.0, 1.0);
    final from = (s - 0.012).clamp(0.0, 1.0);
    final to = (s + 0.012).clamp(0.0, 1.0);
    return Positioned(
      left: 4,
      top: 6,
      width: 318,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              color,
              color,
              color.withValues(alpha: 0),
              color.withValues(alpha: 0),
            ],
            stops: [0, from, to, 1],
          ),
        ),
      ),
    );
  }
}
