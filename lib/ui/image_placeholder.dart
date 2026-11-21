import 'package:flutter/widgets.dart';
import 'package:shimmer/shimmer.dart';

import '../core/motion.dart';
import '../theme/theme.dart';

/// The fill behind a network photo or logo until the bytes land. A shimmer
/// sweeps the tint; reduced motion keeps the tint still.
class IqImagePlaceholder extends StatelessWidget {
  const IqImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.round = false,
  });

  final double? width;
  final double? height;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final fill = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: IqColors.tint,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return fill;
    return Shimmer.fromColors(
      baseColor: IqColors.tint,
      highlightColor: IqColors.tintStrong,
      period: IqDurations.skeletonPulse,
      child: fill,
    );
  }
}
