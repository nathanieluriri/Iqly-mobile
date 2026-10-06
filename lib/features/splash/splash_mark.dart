import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/theme.dart';

enum SplashPhase { dark, spark, lit, settled }

enum _Glyph {
  dark('assets/splash/mark-glyph-dark.svg'),
  spark('assets/splash/mark-glyph-spark.svg'),
  lit('assets/splash/mark-glyph-lit.svg');

  const _Glyph(this.asset);
  final String asset;
}

/// One Splash/Mark state, or a point between two of them: the official
/// logomark geometry with its orange paths recoloured for the boot sequence
/// (the glyphs crossfade, as Figma's Smart Animate tweens their colours), a
/// cream base and an accent halo.
class SplashMarkPose {
  const SplashMarkPose({
    required this.mark,
    required this.baseOpacity,
    required this.glyphs,
    required this.halo,
    required this.haloOpacity,
    required this.haloBlur,
  });

  final double mark;
  final double baseOpacity;

  /// How much of the dark, spark and lit glyphs shows.
  final List<double> glyphs;
  final double halo;
  final double haloOpacity;
  final double haloBlur;

  static SplashMarkPose of(SplashPhase phase) => switch (phase) {
    SplashPhase.dark => const SplashMarkPose(
      mark: 88,
      baseOpacity: 0.9,
      glyphs: [1, 0, 0],
      halo: 56,
      haloOpacity: 0,
      haloBlur: 16,
    ),
    SplashPhase.spark => const SplashMarkPose(
      mark: 92,
      baseOpacity: 0.95,
      glyphs: [0, 1, 0],
      halo: 110,
      haloOpacity: 0.18,
      haloBlur: 24,
    ),
    SplashPhase.lit => const SplashMarkPose(
      mark: 100,
      baseOpacity: 1,
      glyphs: [0, 0, 1],
      halo: 150,
      haloOpacity: 0.35,
      haloBlur: 32,
    ),
    SplashPhase.settled => const SplashMarkPose(
      mark: 96,
      baseOpacity: 1,
      glyphs: [0, 0, 1],
      halo: 120,
      haloOpacity: 0.2,
      haloBlur: 28,
    ),
  };

  static SplashMarkPose lerp(SplashMarkPose a, SplashMarkPose b, double t) =>
      SplashMarkPose(
        mark: lerpDouble(a.mark, b.mark, t)!,
        baseOpacity: lerpDouble(a.baseOpacity, b.baseOpacity, t)!,
        glyphs: [
          for (var i = 0; i < 3; i++) lerpDouble(a.glyphs[i], b.glyphs[i], t)!,
        ],
        halo: lerpDouble(a.halo, b.halo, t)!,
        haloOpacity: lerpDouble(a.haloOpacity, b.haloOpacity, t)!,
        haloBlur: lerpDouble(a.haloBlur, b.haloBlur, t)!,
      );
}

/// The 240 x 240 Splash/Mark tile at [pose], scaled to [tile].
class SplashMark extends StatelessWidget {
  const SplashMark({super.key, required this.pose, required this.tile});

  final SplashMarkPose pose;
  final double tile;

  static const double designTile = 240;

  @override
  Widget build(BuildContext context) {
    final scale = tile / designTile;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(
          dimension: pose.halo * scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: IqColors.accent.withValues(alpha: pose.haloOpacity),
                  blurRadius: _blurRadius(pose.haloBlur * scale),
                ),
              ],
            ),
          ),
        ),
        SizedBox.square(
          dimension: pose.mark * scale,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: pose.baseOpacity,
                child: SvgPicture.asset('assets/splash/mark-base.svg'),
              ),
              for (final glyph in _Glyph.values)
                Opacity(
                  opacity: pose.glyphs[glyph.index],
                  child: SvgPicture.asset(glyph.asset),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Figma's layer blur radius is a Gaussian with sigma = radius / 2;
  /// BoxShadow derives sigma as blurRadius * 0.57735 + 0.5.
  static double _blurRadius(double figmaRadius) =>
      (figmaRadius / 2 - 0.5) / 0.57735;
}
