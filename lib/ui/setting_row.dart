import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'switch.dart';

/// Exp/SettingRow: a preference row, label, one-line description and an
/// Exp/Switch. The whole row is the tap target and flips [state] through
/// [onChanged]. The divider is a 1 px line inset 16 on both sides.
///
/// Figma over brief: the row is a white Color/card band with no radius.
class IqSettingRow extends StatelessWidget {
  const IqSettingRow({
    super.key,
    this.label = 'Brief closing soon',
    this.description = 'A day before, and again an hour before',
    this.showDescription = true,
    this.divider = true,
    this.state = IqSwitchState.off,
    this.onChanged,
  });

  final String label;
  final String description;
  final bool showDescription;
  final bool divider;
  final IqSwitchState state;
  final ValueChanged<IqSwitchState>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () => onChanged(
                state == IqSwitchState.on
                    ? IqSwitchState.off
                    : IqSwitchState.on,
              ),
        child: Container(
          color: IqColors.card,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: IqSpace.s4,
                  vertical: IqSpace.s3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: IqText.bodyStrong.copyWith(
                              color: IqColors.fg,
                            ),
                          ),
                          if (showDescription) ...[
                            const SizedBox(height: 1),
                            Text(
                              description,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: IqText.small.copyWith(color: IqColors.fg3),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    IqSwitch(state: state, onChanged: onChanged),
                  ],
                ),
              ),
              if (divider)
                const Positioned(
                  left: IqSpace.s4,
                  right: IqSpace.s4,
                  bottom: 0,
                  height: 1,
                  child: ColoredBox(color: IqColors.line),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
