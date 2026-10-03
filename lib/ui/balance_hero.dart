import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'button.dart';

/// Exp/BalanceHero: the wallet hero on ink. [amount] and [decimals] are
/// separate so the figure sets in Bricolage at two sizes. Earned and On hold
/// must foot: earned = withdrawn + on hold + available. [holdLabel] carries
/// the pending count (a plain text layer in Figma).
///
/// The iQLY Ink Wash is a WebGPU fbm shader in Figma that Flutter cannot run
/// without a shader asset; here it is an approximation in ember pools masked
/// to the same top-right flare, drifting slowly (still under reduced motion).
///
/// Figma over brief: the Inverse Withdraw button keeps its orange sticker.
///
/// [figureBuilder] draws the four figures; a screen passes one to animate
/// them (Figma has no motion here). Plain [Text] by default.
class IqBalanceHero extends StatelessWidget {
  const IqBalanceHero({
    super.key,
    this.amount = '₦12,500',
    this.decimals = '.00',
    this.onHold = '₦10,000.00',
    this.earned = '₦62,500.00',
    this.holdLabel = 'On hold · 1 pending',
    this.onWithdraw,
    this.figureBuilder,
  });

  final String amount;
  final String decimals;
  final String onHold;
  final String earned;
  final String holdLabel;
  final VoidCallback? onWithdraw;
  final Widget Function(String text, TextStyle style)? figureBuilder;

  Widget _figure(String text, TextStyle style) =>
      figureBuilder?.call(text, style) ?? Text(text, style: style);

  @override
  Widget build(BuildContext context) {
    final label = IqText.mono.copyWith(
      color: IqColors.sidebarFg.withValues(alpha: 0.7),
    );
    final value = IqText.smallStrong.copyWith(color: IqColors.sidebarFg);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: IqColors.brand,
        child: Stack(
          children: [
            const Positioned.fill(child: _InkWash()),
            Padding(
              padding: const EdgeInsets.all(IqSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Available to withdraw'.toUpperCase(),
                    style: IqText.mono.copyWith(
                      color: IqColors.sidebarFg.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: IqSpace.s1p5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: _figure(
                          amount,
                          IqText.display.copyWith(color: IqColors.sidebarFg),
                        ),
                      ),
                      const SizedBox(width: IqSpace.s0p5),
                      _figure(
                        decimals,
                        IqText.figureSmall.copyWith(color: IqColors.sidebarFg),
                      ),
                    ],
                  ),
                  const SizedBox(height: IqSpace.s1p5),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: IqSpace.s1p5),
                    // A Wrap so large text drops LIFETIME EARNED to a
                    // second line instead of overflowing the card.
                    child: Wrap(
                      spacing: IqSpace.s6,
                      runSpacing: IqSpace.s1p5,
                      children: [
                        _Stat(
                          label: holdLabel.toUpperCase(),
                          labelStyle: label,
                          value: _figure(onHold, value),
                        ),
                        _Stat(
                          label: 'Lifetime earned'.toUpperCase(),
                          labelStyle: label,
                          value: _figure(earned, value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: IqSpace.s1p5),
                  IqButton(
                    label: 'Withdraw',
                    kind: IqButtonKind.inverse,
                    width: double.infinity,
                    onTap: onWithdraw,
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.labelStyle,
  });

  final String label;
  final Widget value;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: IqSpace.s0p5),
        value,
      ],
    );
  }
}

class _InkWash extends StatefulWidget {
  const _InkWash();

  static const Duration loop = IqDurations.inkWash;

  @override
  State<_InkWash> createState() => _InkWashState();
}

class _InkWashState extends State<_InkWash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: _InkWash.loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  // Ember pools as (x, y, radius, alpha, phase) in the 358 x 164 wash.
  static const _ember = [
    (322.0, 30.0, 104.0, 0.8, 0.0),
    (270.0, 62.0, 64.0, 0.55, 1.7),
    (346.0, 100.0, 60.0, 0.7, 3.1),
    (236.0, 18.0, 52.0, 0.45, 4.4),
    (300.0, 8.0, 36.0, 0.6, 2.2),
    (352.0, 52.0, 30.0, 0.5, 5.0),
  ];

  @override
  Widget build(BuildContext context) {
    // Figma masks the wash with a linear flare from (250.6, 102) to
    // (331.5, 31) on the 358 x 204 card.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment(250.6 / 358 * 2 - 1, 102 / 204 * 2 - 1),
        end: Alignment(331.508 / 358 * 2 - 1, 31.0075 / 204 * 2 - 1),
        colors: [
          IqColors.sidebarFg.withValues(alpha: 0),
          IqColors.sidebarFg.withValues(alpha: 0.35),
          IqColors.sidebarFg,
        ],
        stops: const [0, 0.35, 1],
      ).createShader(rect),
      child: Opacity(
        opacity: 0.85,
        child: LayoutBuilder(
          builder: (context, box) {
            final sx = box.maxWidth / 358;
            return AnimatedBuilder(
              animation: _drift,
              builder: (context, _) {
                final t = _drift.value * 2 * math.pi;
                Widget pool((double, double, double, double, double) p) {
                  final (x, y, r, alpha, phase) = p;
                  final dx = 10 * math.sin(t + phase);
                  final dy = 6 * math.cos(t * 2 + phase);
                  return Positioned(
                    left: (x + dx) * sx - r,
                    top: y + dy - r,
                    width: r * 2,
                    height: r * 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            IqColors.accent.withValues(alpha: alpha),
                            IqColors.accent.withValues(alpha: alpha * 0.6),
                            IqColors.accent.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.55, 1],
                        ),
                      ),
                    ),
                  );
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 164,
                      // Fades out before the wash box ends so no pool shows a
                      // clipped edge.
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            IqColors.sidebarFg,
                            IqColors.sidebarFg,
                            IqColors.sidebarFg.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.55, 1],
                        ).createShader(rect),
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [for (final p in _ember) pool(p)],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
