import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqBizCrumbState { link, current }

/// Exp/Biz/Crumb (1730:17046): one breadcrumb step, 44 tall for touch. A
/// Link is fg2 with the chevron after it and opens its page; Current is fg
/// and ends the trail.
class IqBizCrumb extends StatelessWidget {
  const IqBizCrumb({
    super.key,
    required this.label,
    this.state = IqBizCrumbState.link,
    this.onTap,
  });

  final String label;
  final IqBizCrumbState state;
  final VoidCallback? onTap;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final link = state == IqBizCrumbState.link;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: IqWebText.bodySmall.copyWith(
        color: link ? IqColors.fg2 : IqColors.fg,
      ),
    );
    if (!link) {
      return SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: text,
        ),
      );
    }
    return IqPressable(
      onTap: onTap,
      tactile: false,
      semanticLabel: label,
      builder: (context, pressed) => SizedBox(
        height: height,
        child: Opacity(
          opacity: pressed ? 0.6 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: text),
              const SizedBox(width: IqSpace.s1),
              const IqIcon(IqIcons.forward, size: 14, color: IqColors.fg3),
            ],
          ),
        ),
      ),
    );
  }
}
