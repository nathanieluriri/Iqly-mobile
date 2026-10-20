import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

enum IqSupportStickerSize { small, large }

/// Exp/SupportSticker: iQLY support's round "iQ" mark on the accent disc,
/// 20 beside a sender name and 40 on a thread or its row. The disc bleeds
/// one point past the frame, as Figma draws it.
class IqSupportSticker extends StatelessWidget {
  const IqSupportSticker({super.key, this.size = IqSupportStickerSize.large});

  final IqSupportStickerSize size;

  @override
  Widget build(BuildContext context) {
    final large = size == IqSupportStickerSize.large;
    final side = large ? 40.0 : 20.0;
    final bleed = large ? 2.0 : 1.0;
    return SizedBox(
      width: side,
      height: side,
      child: OverflowBox(
        maxWidth: side + bleed * 2,
        maxHeight: side + bleed * 2,
        child: Container(
          width: side + bleed * 2,
          height: side + bleed * 2,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: IqColors.accent,
            shape: BoxShape.circle,
          ),
          child: Text(
            'iQ',
            style: (large ? IqText.button : IqText.label).copyWith(
              color: IqColors.brand,
            ),
          ),
        ),
      ),
    );
  }
}
