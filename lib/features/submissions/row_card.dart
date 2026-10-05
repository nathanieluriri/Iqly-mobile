import 'package:flutter/widgets.dart';

import '../../theme/theme.dart';

/// The frames' card around a lone Exp/ListRow or a short stack of them
/// (193:9573 group, 324:14478 winnings-summary): card fill, 1 line inside,
/// clipped to [radius].
class RowCard extends StatelessWidget {
  const RowCard({super.key, required this.child, this.radius = 16});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: shape,
        border: Border.all(color: IqColors.line),
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: ColoredBox(
          color: IqColors.card,
          child: Padding(padding: const EdgeInsets.all(1), child: child),
        ),
      ),
    );
  }
}
