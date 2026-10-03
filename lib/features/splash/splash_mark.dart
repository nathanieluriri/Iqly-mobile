import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/motion.dart';
import '../../theme/theme.dart';

enum SplashPhase { dark, spark, lit, settled }

enum _Glyph {
  dark('assets/splash/mark-glyph-dark.svg'),
  spark('assets/splash/mark-glyph-spark.svg'),
  lit('assets/splash/mark-glyph-lit.svg');

  const _Glyph(this.asset);
  final String asset;
}

/// One Splash/Mark state: the official logomark geometry with its orange
/// paths recoloured for the boot sequence, a cream base and an accent halo.
class _MarkSpec {
  const _MarkSpec({
    required this.mark,
    required this.baseOpacity,
    required this.glyph,
    required this.halo,
    required this.haloOpacity,
    required this.haloBlur,
  });

  final double mark;
  final double baseOpacity;
  final _Glyph glyph;
  final double halo;
  final double haloOpacity;
  final double haloBlur;

  static _MarkSpec of(SplashPhase phase) => switch (phase) {
    SplashPhase.dark => const _MarkSpec(
      mark: 88,
      baseOpacity: 0.9,
      glyph: _Glyph.dark,
      halo: 56,
      haloOpacity: 0,
      haloBlur: 16,
    ),
    SplashPhase.spark => const _MarkSpec(
      mark: 92,
      baseOpacity: 0.95,
      glyph: _Glyph.spark,
      halo: 110,
      haloOpacity: 0.18,
      haloBlur: 24,
    ),
    SplashPhase.lit => const _MarkSpec(
      mark: 100,
      baseOpacity: 1,
      glyph: _Glyph.lit,
      halo: 150,
      haloOpacity: 0.35,
      haloBlur: 32,
    ),
    SplashPhase.settled => const _MarkSpec(
      mark: 96,
      baseOpacity: 1,
      glyph: _Glyph.lit,
      halo: 120,
      haloOpacity: 0.2,
      haloBlur: 28,
    ),
  };
}

/// The 240 x 240 Splash/Mark tile, scaled to [tile]. Layers crossfade so the
/// glyph colours tween exactly as Figma's Smart Animate does.
class SplashMark extends StatelessWidget {
  const SplashMark({
    super.key,
    required this.phase,
    required this.duration,
    required this.tile,
  });

  final SplashPhase phase;
  final Duration duration;
  final double tile;

  static const double designTile = 240;

  @override
  Widget build(BuildContext context) {
    final spec = _MarkSpec.of(phase);
    final scale = tile / designTile;
    const curve = IqCurves.easeInOut;
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: duration,
          curve: curve,
          width: spec.halo * scale,
          height: spec.halo * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: IqColors.accent.withValues(alpha: spec.haloOpacity),
                blurRadius: _blurRadius(spec.haloBlur * scale),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: duration,
          curve: curve,
          width: spec.mark * scale,
          height: spec.mark * scale,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                duration: duration,
                curve: curve,
                opacity: spec.baseOpacity,
                child: SvgPicture.asset('assets/splash/mark-base.svg'),
              ),
              for (final glyph in _Glyph.values)
                AnimatedOpacity(
                  duration: duration,
                  curve: curve,
                  opacity: glyph == spec.glyph ? 1 : 0,
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
