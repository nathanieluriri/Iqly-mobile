import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'cover_with_logo.dart';
import 'sample_cover.dart';
import 'sample_logo.dart';

enum IqBrandHeaderLayout { centered, leading }

/// Exp/BrandHeader: the business header of the poll sheet (Centered: the
/// logo floats in the middle of the photo edge) and the full-screen poll
/// page (Leading: the logo moves left beside the business name).
///
/// [brand] is the Figma prop name; it holds the business name. A detail
/// longer than a line (the done line, 480:22679) wraps to a second rather
/// than being cut, and the header grows to hold it.
///
/// Figma 480:22679 runs the done line on one line past the sheet's 16 pt
/// margins; here it wraps inside them.
class IqBrandHeader extends StatelessWidget {
  const IqBrandHeader({
    super.key,
    this.layout = IqBrandHeaderLayout.centered,
    this.brand = 'Orchid Foods',
    this.detail = '2 open polls',
    this.cover = const IqSampleCover(IqSampleLogoBrand.orchidFoods),
    this.logo = const IqSampleLogo(IqSampleLogoBrand.orchidFoods),
  });

  final IqBrandHeaderLayout layout;
  final String brand;
  final String detail;
  final Widget cover;
  final Widget logo;

  @override
  Widget build(BuildContext context) {
    return layout == IqBrandHeaderLayout.centered ? _centered() : _leading();
  }

  Widget _centered() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 207),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => CoverWithLogo(
              size: Size(constraints.maxWidth, 128),
              radius: IqRadius.xl2,
              cover: cover,
              logo: logo,
              logoOffset: Offset(constraints.maxWidth / 2 - 28, 100),
              logoSize: 56,
              logoInset: IqSpace.s1,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            brand,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: IqText.bodyStrong.copyWith(color: IqColors.fg),
          ),
          const SizedBox(height: IqSpace.s0p5),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: IqText.small.copyWith(color: IqColors.fg2),
          ),
        ],
      ),
    );
  }

  Widget _leading() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 288),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => CoverWithLogo(
              size: Size(constraints.maxWidth, 220),
              cover: cover,
              logo: logo,
              logoOffset: const Offset(IqSpace.s4, 188),
              logoSize: 64,
              logoInset: IqSpace.s1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(92, IqSpace.s2, IqSpace.s4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.headline.copyWith(color: IqColors.fg),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: IqText.small.copyWith(color: IqColors.fg2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
