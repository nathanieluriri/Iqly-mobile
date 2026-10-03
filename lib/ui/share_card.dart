import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme.dart';
import 'illustration.dart';
import 'brand_logo.dart';

/// Exp/ShareCard: the winner celebration card on dark paper, official logo,
/// orange marker under the figure and the brush trophy. Give it a GlobalKey
/// and call [capture] for the 3x image the system share sheet sends.
///
/// Figma over its description: 358 x 414, not 358 x 440.
/// Figma over brief: the eyebrow prop is Brand ("WINNER · ORCHID FOODS"), screens override it.
/// Figma over brief: the logo is fixed (On dark tone), not a prop.
/// Figma over brief: text on ink is Color/sidebar-fg, not the brand-fg tokens.
/// Figma over brief: the site line is Mob/Mono, so it reads IQLY.NET.
/// Figma over brief: the trophy ink is recoloured cream for the dark card.
class IqShareCard extends StatelessWidget {
  const IqShareCard({
    super.key,
    this.brand = 'WINNER · ORCHID FOODS',
    this.title = 'Sunday is data day',
    this.amount = '₦12,500',
    this.brief = 'Why do Lagosians skip mobile banking on Sundays?',
    this.name = 'ADAEZE OKAFOR',
  });

  final String brand;
  final String title;
  final String amount;
  final String brief;
  final String name;

  static const double width = 358;
  static const double exportPixelRatio = 3;

  /// Renders the card behind [key] (the key passed to this widget) to an
  /// image at [pixelRatio].
  static Future<ui.Image> capture(
    GlobalKey key, {
    double pixelRatio = exportPixelRatio,
  }) {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return boundary.toImage(pixelRatio: pixelRatio);
  }

  @override
  Widget build(BuildContext context) {
    final mono = IqText.mono.copyWith(color: IqColors.sidebarFg);
    return RepaintBoundary(
      child: Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: IqColors.brand,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 196,
              top: 100,
              child: SvgPicture.asset(
                IqIllustrations.trophy.asset,
                width: 160,
                height: 128,
                excludeFromSemantics: true,
                colorMapper: const _InkOnDark(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(IqSpace.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const IqBrandLogo(
                      tone: IqBrandTone.onDark,
                      height: 28,
                    ),
                  ),
                  const SizedBox(height: IqSpace.s4),
                  Text(
                    brand.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono,
                  ),
                  const SizedBox(height: IqSpace.s4),
                  const SizedBox(height: 120),
                  const SizedBox(height: IqSpace.s4),
                  Text(
                    title,
                    style: IqText.title.copyWith(color: IqColors.sidebarFg),
                  ),
                  const SizedBox(height: IqSpace.s4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _Marker(amount: amount),
                  ),
                  const SizedBox(height: IqSpace.s4),
                  Text(
                    brief,
                    style: IqText.small.copyWith(color: IqColors.sidebarFg),
                  ),
                  const SizedBox(height: IqSpace.s4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mono,
                        ),
                      ),
                      const SizedBox(width: IqSpace.s2),
                      Text('iqly.net'.toUpperCase(), style: mono),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Transform.rotate(
            angle: -1.78 * math.pi / 180,
            child: const ColoredBox(color: IqColors.accent),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: IqSpace.s2p5,
            vertical: IqSpace.s0p5,
          ),
          child: Text(
            amount,
            style: IqText.figure.copyWith(color: IqColors.brand),
          ),
        ),
      ],
    );
  }
}

class _InkOnDark extends ColorMapper {
  const _InkOnDark();

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => color == IqColors.brand ? IqColors.sidebarFg : color;
}
