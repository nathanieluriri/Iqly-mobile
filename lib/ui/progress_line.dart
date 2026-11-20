import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The 4 pt bar ContinueCard uses under its title: a line track with a
/// primary fill. It belongs in the text column, never under the photo.
class IqProgressLine extends StatelessWidget {
  const IqProgressLine({super.key, required this.value});

  /// How far the work has got, 0 to 1.
  final double value;

  static const double height = 4;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: IqColors.line)),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              heightFactor: 1,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: IqColors.primary,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
