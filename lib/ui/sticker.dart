import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The sticker shadow: a filled copy of the pill offset 4,4 behind it. On
/// press the pill drops onto the shadow (Figma draws it at 3,3) and the
/// shadow disappears, 120 ms ease-out. Primary buttons and the next button
/// only; never chips, tabs or cards.
class Sticker extends StatelessWidget {
  const Sticker({
    super.key,
    required this.child,
    required this.radius,
    this.color = IqColors.accent,
    this.pressed = false,
    this.visible = true,
  });

  final Widget child;
  final double radius;
  final Color color;
  final bool pressed;
  final bool visible;

  static const double offset = 4;
  static const double pressOffset = 3;
  static const Duration duration = Duration(milliseconds: 120);

  @override
  Widget build(BuildContext context) {
    final drop = pressed ? pressOffset : 0.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: offset,
          top: offset,
          right: -offset,
          bottom: -offset,
          child: AnimatedOpacity(
            duration: duration,
            curve: Curves.easeOut,
            opacity: visible && !pressed ? 1 : 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(drop, drop, 0),
          child: child,
        ),
      ],
    );
  }
}
