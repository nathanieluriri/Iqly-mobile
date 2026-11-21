import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// The fill behind a network photo or logo until the bytes land.
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
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: IqColors.tint,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}
