import 'package:flutter/widgets.dart';

import 'sample_logo.dart';

export 'sample_logo.dart' show IqSampleLogoBrand;

/// Sample/Cover: a business photo, 320 x 200 in Figma. The file is the
/// source photo Figma fills from (scaled to 800 on its long side), so
/// BoxFit.cover crops it the way the Figma FILL does at any size.
class IqSampleCover extends StatelessWidget {
  const IqSampleCover(this.brand, {super.key, this.shot = 1});

  final IqSampleLogoBrand brand;
  final int shot;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      brand.cover(shot),
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      gaplessPlayback: true,
    );
  }
}
