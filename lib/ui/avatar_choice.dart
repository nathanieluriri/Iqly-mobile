import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'avatar.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqAvatarChoiceKind { avatar, create, emoji }

/// Figma State=Default is [standard].
enum IqAvatarChoiceState { standard, selected }

/// Exp/Avatar/Choice: a tile of the avatar picker. Avatar holds any avatar
/// (a person, a buddy, an emoji avatar, the saved photo) at 70 in an 82
/// target; Create is the dashed tint disc with the pencil; Emoji is the 57
/// emoji tile on a tint bubble. Selected adds a 3 primary ring.
class IqAvatarChoice extends StatelessWidget {
  const IqAvatarChoice({
    super.key,
    this.kind = IqAvatarChoiceKind.avatar,
    this.state = IqAvatarChoiceState.standard,
    this.avatar = const IqPersonAvatar(IqAvatarLook()),
    this.emoji = '😄',
    this.semanticLabel,
    this.onTap,
  });

  final IqAvatarChoiceKind kind;
  final IqAvatarChoiceState state;
  final IqAvatarSpec avatar;
  final String emoji;
  final String? semanticLabel;
  final VoidCallback? onTap;

  static const double size = 82;
  static const double emojiSize = 57;
  static const double ring = 3;

  @override
  Widget build(BuildContext context) {
    final selected = state == IqAvatarChoiceState.selected;
    final emojiKind = kind == IqAvatarChoiceKind.emoji;
    final box = emojiKind ? emojiSize : size;
    final inner = emojiKind ? 51.0 : 70.0;
    final content = switch (kind) {
      IqAvatarChoiceKind.avatar => IqAvatar(avatar, size: inner),
      IqAvatarChoiceKind.create => SizedBox.square(
        dimension: inner,
        child: CustomPaint(
          painter: _DashedDisc(),
          child: const Center(
            child: IqIcon(IqIcons.pencil, size: 28, color: IqColors.brand),
          ),
        ),
      ),
      IqAvatarChoiceKind.emoji => Container(
        width: inner,
        height: inner,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: IqColors.tint,
          shape: BoxShape.circle,
        ),
        child: Text(
          emoji,
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: IqText.headline,
        ),
      ),
    };
    return Semantics(
      selected: selected,
      button: true,
      child: IqPressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        haptic: IqHaptics.select,
        builder: (context, pressed) => PressDim(
          pressed: pressed,
          child: AnimatedContainer(
            duration: motion(context, IqDurations.tick),
            curve: IqCurves.easeOut,
            width: box,
            height: box,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? IqColors.primary
                    : IqColors.primary.withValues(alpha: 0),
                width: ring,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// The Create disc: tint with a 2 primary inside stroke dashed 5, 4. Plain
/// geometry, not a brush shape.
class _DashedDisc extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(centre, radius, Paint()..color = IqColors.tint);
    dashedCircle(canvas, centre, radius - 1, 2, IqColors.primary);
  }

  @override
  bool shouldRepaint(_DashedDisc old) => false;
}

/// A [width] stroke around a circle of [radius], dashed 5 on 4 off as
/// Figma dashes it.
void dashedCircle(
  Canvas canvas,
  Offset centre,
  double radius,
  double width,
  Color colour,
) {
  final paint = Paint()
    ..color = colour
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;
  final circumference = 2 * math.pi * radius;
  for (var d = 0.0; d < circumference; d += 9) {
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2 + d / radius,
      math.min(5, circumference - d) / radius,
      false,
      paint,
    );
  }
}
