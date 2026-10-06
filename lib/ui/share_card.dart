import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
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
/// Figma over its description: 358 x 418, not 358 x 440.
/// Figma over brief: the eyebrow prop is Brand ("Winner · Orchid Foods"), screens override it.
/// Figma over brief: the logo is fixed (On dark tone), not a prop.
/// Figma over brief: text on ink is Color/sidebar-fg, not the brand-fg tokens.
/// Figma over brief: since the 5 Oct update the eyebrow is Mob/Label, the
/// name Mob/Small strong and the site line Mob/Small (iqly.net), no mono.
/// Figma over brief: the trophy ink is recoloured cream for the dark card.
///
/// The Winner celebration (MOTION-SPEC §5.33) runs [markerReveal] and
/// [accentReveal] from 0 to 1: the marker under the amount and the trophy's
/// orange sweep wipe in left to right. Left null they are drawn whole.
class IqShareCard extends StatelessWidget {
  const IqShareCard({
    super.key,
    this.brand = 'WINNER · ORCHID FOODS',
    this.title = 'Sunday is data day',
    this.amount = '₦12,500',
    this.brief = 'Why do Lagosians skip mobile banking on Sundays?',
    this.name = 'ADAEZE OKAFOR',
    this.markerReveal,
    this.accentReveal,
  });

  final String brand;
  final String title;
  final String amount;
  final String brief;
  final String name;
  final Animation<double>? markerReveal;
  final Animation<double>? accentReveal;

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
              child: _Trophy(reveal: accentReveal),
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
                    brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IqText.label.copyWith(color: IqColors.sidebarFg),
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
                    child: _Marker(amount: amount, reveal: markerReveal),
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
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: IqText.smallStrong.copyWith(
                            color: IqColors.sidebarFg,
                          ),
                        ),
                      ),
                      const SizedBox(width: IqSpace.s2),
                      Text(
                        'iqly.net',
                        style: IqText.small.copyWith(color: IqColors.sidebarFg),
                      ),
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
  const _Marker({required this.amount, this.reveal});

  final String amount;
  final Animation<double>? reveal;

  @override
  Widget build(BuildContext context) {
    final reveal = this.reveal;
    final band = Transform.rotate(
      angle: -1.78 * math.pi / 180,
      child: const ColoredBox(color: IqColors.accent),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: reveal == null
              ? band
              : AnimatedBuilder(
                  animation: reveal,
                  child: band,
                  builder: (context, child) =>
                      ClipRect(clipper: _Sweep(reveal.value), child: child),
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

/// The trophy, whole or as its two layers with the orange sweep (x 146.75
/// to 181.25 of the 200 wide drawing) wiping in on [reveal].
class _Trophy extends StatelessWidget {
  const _Trophy({this.reveal});

  final Animation<double>? reveal;

  static const _sweepFrom = 146.75 / 200;
  static const _sweepTo = 181.25 / 200;

  Widget _layer(String? only) => SvgPicture.asset(
    IqIllustrations.trophy.asset,
    width: 160,
    height: 128,
    excludeFromSemantics: true,
    colorMapper: _InkOnDark(only: only),
  );

  @override
  Widget build(BuildContext context) {
    final reveal = this.reveal;
    if (reveal == null) return _layer(null);
    return Stack(
      children: [
        _layer('ink'),
        AnimatedBuilder(
          animation: reveal,
          child: _layer('accent'),
          builder: (context, child) => ClipRect(
            clipper: _Sweep(
              _sweepFrom + (_sweepTo - _sweepFrom) * reveal.value,
              whole: reveal.value >= 1,
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Shows the left [reveal] share of the box; nothing is clipped once
/// [whole] (the marker band is tilted past its box).
class _Sweep extends CustomClipper<Rect> {
  _Sweep(this.reveal, {bool? whole}) : whole = whole ?? reveal >= 1;

  final double reveal;
  final bool whole;

  @override
  Rect getClip(Size size) {
    final reach = size.longestSide;
    return Rect.fromLTRB(
      -reach,
      -reach,
      whole ? size.width + reach : size.width * reveal.clamp(0.0, 1.0),
      size.height + reach,
    );
  }

  @override
  bool shouldReclip(_Sweep old) => old.reveal != reveal || old.whole != whole;
}

/// Recolours the trophy's ink cream for the dark card; [only] keeps one of
/// its two layers ("ink" or "accent") and clears the other.
class _InkOnDark extends ColorMapper {
  const _InkOnDark({this.only});

  final String? only;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    final only = this.only;
    if (only != null && (id == 'accent') != (only == 'accent')) {
      return Colors.transparent;
    }
    return color == IqColors.brand ? IqColors.sidebarFg : color;
  }

  @override
  bool operator ==(Object other) => other is _InkOnDark && other.only == only;

  @override
  int get hashCode => only.hashCode;
}
