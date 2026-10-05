import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

/// Exp/FaqRow: one question in the Help list. Tapping opens Exp/FaqSheet
/// with the answer.
class IqFaqRow extends StatelessWidget {
  const IqFaqRow({
    super.key,
    this.question = 'When do I get paid after a brief closes?',
    this.divider = true,
    this.onTap,
  });

  final String question;
  final bool divider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      semanticLabel: question,
      builder: (context, pressed) => AnimatedContainer(
        duration: pressed ? IqDurations.dim : IqDurations.release,
        constraints: const BoxConstraints(minHeight: 56),
        color: pressed ? IqColors.panel : IqColors.bg.withValues(alpha: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      question,
                      style: IqText.body.copyWith(color: IqColors.fg),
                    ),
                  ),
                  const SizedBox(width: IqSpace.s3),
                  const IqIcon(IqIcons.forward, size: 18, color: IqColors.fg3),
                ],
              ),
            ),
            SizedBox(
              height: 1,
              width: double.infinity,
              child: divider ? const ColoredBox(color: IqColors.line) : null,
            ),
          ],
        ),
      ),
    );
  }
}
