import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma Exp/Illustration, 200 x 160: an ink layer and an accent layer in
/// token colours, drawn with the icon brush. Bulb, Wallet, Trophy and Bell
/// are empty states; the rest mark onboarding and outcome moments.
enum IqIllustrations {
  bulb('bulb'),
  wallet('wallet'),
  trophy('trophy'),
  bell('bell'),
  card('card'),
  pin('pin'),
  pick('pick'),
  resume('return'),
  cheer('cheer'),
  sprout('sprout'),
  rocket('rocket'),
  megaphone('megaphone');

  const IqIllustrations(this.file);
  final String file;

  String get asset => 'assets/illustrations/$file.svg';
}

class IqIllustration extends StatelessWidget {
  const IqIllustration(this.kind, {super.key, this.width = designWidth});

  final IqIllustrations kind;
  final double width;

  static const double designWidth = 200;
  static const double designHeight = 160;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      kind.asset,
      width: width,
      height: width * designHeight / designWidth,
      excludeFromSemantics: true,
    );
  }
}

/// Figma Exp/Figure, 320 x 340: flat half-body people, token colours only.
enum IqFigures {
  thinker,
  caller,
  reach;

  String get asset => 'assets/illustrations/figure-$name.svg';
}

class IqFigure extends StatelessWidget {
  const IqFigure(this.figure, {super.key, this.width = designWidth});

  final IqFigures figure;
  final double width;

  static const double designWidth = 320;
  static const double designHeight = 340;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      figure.asset,
      width: width,
      height: width * designHeight / designWidth,
      excludeFromSemantics: true,
    );
  }
}

/// Figma Exp/LineArt, 280 x 280 monoline, three keyframes of the landing loop.
enum IqLineArtFrames {
  frame1,
  frame2,
  frame3;

  String get asset => 'assets/illustrations/lineart-${index + 1}.svg';
}

class IqLineArt extends StatelessWidget {
  const IqLineArt(this.frame, {super.key, this.size = designSize});

  final IqLineArtFrames frame;
  final double size;

  static const double designSize = 280;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      frame.asset,
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}
