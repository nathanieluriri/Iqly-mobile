import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma Brand, the sample businesses of the Sample/* sets, in Figma order.
/// [private] stands in for a business that keeps its name out of the feed.
enum IqSampleLogoBrand {
  orchidFoods('Orchid Foods', 'orchid-foods'),
  basketNg('Basket NG', 'basket-ng'),
  kudiBox('Kudi Box', 'kudi-box'),
  sunline('Sunline', 'sunline'),
  unibooks('Unibooks', 'unibooks'),
  harbour('Harbour', 'harbour'),
  voltRiders('Volt Riders', 'volt-riders'),
  swapit('Swapit', 'swapit'),
  garriAndCo('Garri & Co', 'garri-and-co'),
  lagoonLines('Lagoon Lines', 'lagoon-lines'),
  classpay('Classpay', 'classpay'),
  private('Private', 'private');

  const IqSampleLogoBrand(this.label, this.slug);

  final String label;
  final String slug;

  String get logo => 'assets/samples/logos/$slug.svg';

  /// Figma has two shots for every business but [private], which has one.
  int get shots => this == private ? 1 : 2;

  String cover([int shot = 1]) =>
      'assets/samples/covers/$slug-${shot.clamp(1, shots)}.jpg';
}

/// Sample/Logo: a sample business mark, 120 x 120 in Figma and drawn at
/// [size]. Exported unaltered from Figma; never redrawn or recoloured.
class IqSampleLogo extends StatelessWidget {
  const IqSampleLogo(this.brand, {super.key, this.size = 120});

  final IqSampleLogoBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      brand.logo,
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}
