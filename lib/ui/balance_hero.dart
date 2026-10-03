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
/// to the same top-right flare, painted on its own layer and drifting over a
/// 24 s loop; it holds still off screen, with its route covered or its tab
/// hidden, and under reduced motion (spec 5.31, `Figma 37:20`).
///
/// The figures and the pending count roll their changed characters when
/// they change, never on arrival (money is quiet, spec 1.4; build
/// extension).
///
/// Figma over brief: the Inverse Withdraw button keeps its orange sticker.
///
/// [figureBuilder] draws the four figures in place of the rolling text.
///
/// [showWithdraw] off drops the Withdraw button, as the B10 help thread's
/// 146 pt instance does (the button is not a prop in Figma).
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
    this.showWithdraw = true,
  });

  final String amount;
  final String decimals;
  final String onHold;
  final String earned;
  final String holdLabel;
  final VoidCallback? onWithdraw;
  final Widget Function(String text, TextStyle style)? figureBuilder;
  final bool showWithdraw;

  Widget _figure(String text, TextStyle style) =>
      figureBuilder?.call(text, style) ?? RollingText(text, style: style);

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
                  if (showWithdraw) ...[
                    const SizedBox(height: IqSpace.s1p5),
                    IqButton(
                      label: 'Withdraw',
                      kind: IqButtonKind.inverse,
                      width: double.infinity,
                      onTap: onWithdraw,
                    ),
                  ],
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
        RollingText(label, style: labelStyle),
        const SizedBox(height: IqSpace.s0p5),
        value,
      ],
    );
  }
}

class _InkWash extends StatefulWidget {
  const _InkWash();

  @override
  State<_InkWash> createState() => _InkWashState();
}

class _InkWashState extends State<_InkWash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: IqDurations.inkWash,
  );
  bool _visible = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  void _onVisible(bool visible) {
    _visible = visible;
    _sync();
  }

  void _sync() {
    final run = _visible && !_reduced;
    if (run && !_drift.isAnimating) {
      _drift.repeat();
    } else if (!run && _drift.isAnimating) {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Figma masks the wash with a linear flare from (250.6, 102) to
    // (331.5, 31) on the 358 x 204 card.
    return FirstSeen(
      onVisible: _onVisible,
      child: RepaintBoundary(
        child: ShaderMask(
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
            child: Stack(
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
                    child: CustomPaint(painter: _EmberPainter(_drift)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The ember pools, repainted from the drift without a layout.
class _EmberPainter extends CustomPainter {
  _EmberPainter(this.drift) : super(repaint: drift);

  final Animation<double> drift;

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
  void paint(Canvas canvas, Size size) {
    final t = drift.value * 2 * math.pi;
    final sx = size.width / 358;
    canvas.clipRect(Offset.zero & size, doAntiAlias: false);
    for (final (x, y, r, alpha, phase) in _ember) {
      final pool = Rect.fromCircle(
        center: Offset(
          (x + 10 * math.sin(t + phase)) * sx,
          y + 6 * math.cos(t * 2 + phase),
        ),
        radius: r,
      );
      final shader = RadialGradient(
        colors: [
          IqColors.accent.withValues(alpha: alpha),
          IqColors.accent.withValues(alpha: alpha * 0.6),
          IqColors.accent.withValues(alpha: 0),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(pool);
      canvas.drawRect(pool, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(_EmberPainter oldDelegate) => oldDelegate.drift != drift;
}
