import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A decorative vector exported from Figma (brush underlines, strokes,
/// rings), recoloured at runtime through its ink fill. Never redrawn.
class IqVector extends StatelessWidget {
  const IqVector(
    this.asset, {
    super.key,
    required this.color,
    this.width,
    this.height,
    this.fit = BoxFit.fill,
  });

  final String asset;
  final Color color;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
