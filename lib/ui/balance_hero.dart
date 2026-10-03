import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'button.dart';

/// Exp/BalanceHero: the wallet hero on ink. [amount] and [decimals] are
/// separate so the figure sets in Bricolage at two sizes. Earned and On hold
/// must foot: earned = withdrawn + on hold + available. [holdLabel] carries
/// the pending count (a plain text layer in Figma).
///
/// The iQLY Ink Wash is a WebGPU shader in Figma; here it is an ember and
/// paper wash in token colours, masked to the same top-right flare and
/// drifting slowly (still under reduced motion).
///
/// Figma over brief: the Inverse Withdraw button keeps its orange sticker.
class IqBalanceHero extends StatelessWidget {
  const IqBalanceHero({
    super.key,
    this.amount = '₦12,500',
    this.decimals = '.00',
    this.onHold = '₦10,000.00',
    this.earned = '₦62,500.00',
    this.holdLabel = 'On hold · 1 pending',
    this.onWithdraw,
  });

  final String amount;
  final String decimals;
  final String onHold;
  final String earned;
  final String holdLabel;
  final VoidCallback? onWithdraw;

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
                      Text(
                        amount,
                        style: IqText.display.copyWith(
                          color: IqColors.sidebarFg,
                        ),
                      ),
                      const SizedBox(width: IqSpace.s0p5),
                      Text(
                        decimals,
                        style: IqText.figureSmall.copyWith(
                          color: IqColors.sidebarFg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: IqSpace.s1p5),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: IqSpace.s1p5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Stat(
                          label: holdLabel.toUpperCase(),
                          value: onHold,
                          labelStyle: label,
                          valueStyle: value,
                        ),
                        const SizedBox(width: IqSpace.s6),
                        _Stat(
                          label: 'Lifetime earned'.toUpperCase(),
                          value: earned,
                          labelStyle: label,
                          valueStyle: value,
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
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: IqSpace.s0p5),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _InkWash extends StatefulWidget {
  const _InkWash();

  static const Duration loop = Duration(seconds: 24);

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

  // Ember and paper pools as (x, y, radius, phase) in the 358 x 164 wash.
  static const _ember = [
    (322.0, 30.0, 110.0, 0.0),
    (270.0, 70.0, 72.0, 1.7),
    (344.0, 118.0, 80.0, 3.1),
    (232.0, 20.0, 60.0, 4.4),
    (300.0, 150.0, 56.0, 5.6),
  ];
  static const _paper = [(304.0, 54.0, 26.0, 2.2), (340.0, 10.0, 22.0, 5.0)];

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
                Widget pool(
                  (double, double, double, double) p,
                  Color color,
                  double alpha,
                ) {
                  final (x, y, r, phase) = p;
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
                            color.withValues(alpha: alpha),
                            color.withValues(alpha: alpha * 0.7),
                            color.withValues(alpha: 0),
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
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          for (final p in _ember)
                            pool(p, IqColors.accent, 0.95),
                          for (final p in _paper)
                            pool(p, IqColors.sidebarFg, 0.25),
                        ],
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
