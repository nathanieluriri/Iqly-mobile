import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The shared "media-wrap" of the image-led cards: a cover photo clipped to
/// [radius] with the business logo floating on its edge in a white ring.
/// The logo may hang outside the photo, so nothing here clips it.
class CoverWithLogo extends StatelessWidget {
  const CoverWithLogo({
    super.key,
    required this.size,
    required this.cover,
    required this.logo,
    required this.logoOffset,
    required this.logoSize,
    required this.logoInset,
    this.radius = 0,
    this.coverOpacity = 1,
  });

  final Size size;
  final Widget cover;
  final Widget logo;
  final Offset logoOffset;
  final double logoSize;
  final double logoInset;
  final double radius;
  final double coverOpacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Opacity(opacity: coverOpacity, child: cover),
            ),
          ),
          Positioned(
            left: logoOffset.dx,
            top: logoOffset.dy,
            child: Container(
              width: logoSize,
              height: logoSize,
              padding: EdgeInsets.all(logoInset),
              decoration: const BoxDecoration(
                color: IqColors.card,
                shape: BoxShape.circle,
              ),
              child: ClipOval(child: SizedBox.expand(child: logo)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 1 pt line card shell the image-led cards share: white, 18 radius,
/// the stroke painted inside over the content like Figma's inside stroke.
/// Figma counts that stroke in the auto layout, so [inset] pads the child
/// by the stroke width for the cards laid out that way.
class LineCard extends StatelessWidget {
  const LineCard({
    super.key,
    required this.child,
    this.stroke = IqColors.line,
    this.strokeWidth = 1,
    this.color = IqColors.card,
    this.overlay = const [],
    this.inset = false,
  });

  final Widget child;
  final Color stroke;
  final double strokeWidth;
  final Color color;
  final List<Widget> overlay;
  final bool inset;

  static const double radius = IqRadius.xl2;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: shape),
            child: inset
                ? Padding(padding: const EdgeInsets.all(1), child: child)
                : child,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shape,
                  border: Border.all(color: stroke, width: strokeWidth),
                ),
              ),
            ),
          ),
          ...overlay,
        ],
      ),
    );
  }
}
