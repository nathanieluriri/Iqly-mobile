import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import '../core/motion.dart';
import 'image_placeholder.dart';

/// A remote photo or logo: disk-cached by [CachedNetworkImage], with the
/// kit's shimmer while it loads.
class IqNetworkImage extends StatelessWidget {
  const IqNetworkImage({
    super.key,
    required this.url,
    required this.error,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.round = false,
  });

  final String url;
  final Widget error;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: IqDurations.crossfade,
      fadeOutDuration: IqDurations.crossfade,
      placeholder: (_, _) =>
          IqImagePlaceholder(width: width, height: height, round: round),
      errorWidget: (_, _, _) => error,
    );
    if (!round) return image;
    return ClipOval(child: image);
  }
}
