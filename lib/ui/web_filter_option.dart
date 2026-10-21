import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqWebFilterOptionType { radio, checkbox }

/// Exp/Web/FilterOption (local, sync to DS; 1723:13925): a radio or a
/// checkbox with its label, and the count of briefs it leaves on the right.
/// 44 tall, the whole row takes the tap.
class IqWebFilterOption extends StatelessWidget {
  const IqWebFilterOption({
    super.key,
    required this.label,
    this.type = IqWebFilterOptionType.checkbox,
    this.on = false,
    this.count = '',
    this.showCount = true,
    this.onChanged,
  });

  final String label;
  final IqWebFilterOptionType type;
  final bool on;
  final String count;
  final bool showCount;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final radio = type == IqWebFilterOptionType.radio;
    return Semantics(
      checked: on,
      inMutuallyExclusiveGroup: radio,
      label: label,
      excludeSemantics: true,
      child: IqPressable(
        onTap: onChanged == null ? null : () => onChanged!(radio || !on),
        tactile: false,
        builder: (context, pressed) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? IqColors.primary : IqColors.card,
                  shape: radio ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: radio
                      ? null
                      : BorderRadius.circular(IqSpace.s1),
                  border: on
                      ? null
                      : Border.all(
                          color: pressed ? IqColors.fg3 : IqColors.line2,
                          width: 1.5,
                        ),
                ),
                child: !on
                    ? null
                    : radio
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: IqColors.primaryFg,
                          shape: BoxShape.circle,
                        ),
                      )
                    : const IqIcon(
                        IqIcons.check,
                        size: 12,
                        color: IqColors.primaryFg,
                      ),
              ),
              const SizedBox(width: IqSpace.s2p5),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
                  child: Text(
                    label,
                    style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
                  ),
                ),
              ),
              if (showCount && count.isNotEmpty) ...[
                const SizedBox(width: IqSpace.s2),
                Text(
                  count,
                  style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
