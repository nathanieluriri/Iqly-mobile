import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'perforation.dart';

enum IqSkeletonKind { ticket, row, line }

/// Exp/Skeleton: loading placeholders. Ticket mirrors the List TicketCard
/// (main bars, stub bars, perforation at 246), Row mirrors Exp/ListRow,
/// Line is one text line. Bars are brand at 10% and pulse .5 to 1 to .5 over
/// 900 ms on the screen's shared beat, so every bar on a screen is in phase
/// (spec 5.15); still at full under reduced motion. Screens show it through
/// LoadingGate: after [showAfter] of waiting, for at least [minVisible].
///
/// Figma over brief: the Ticket skeleton is a plain tint rectangle (radius 16), no notched silhouette.
/// Figma over brief: its perforation is brand 1 px, dash 3/4, at 20%.
class IqSkeleton extends StatelessWidget {
  const IqSkeleton({super.key, this.kind = IqSkeletonKind.ticket, this.width});

  final IqSkeletonKind kind;

  /// Defaults to the Figma 358.
  final double? width;

  static const Duration pulse = IqDurations.skeletonPulse;
  static const Duration showAfter = IqDurations.skeletonDelay;
  static const Duration minVisible = IqDurations.skeletonMin;

  Widget _bar(
    Animation<double> opacity,
    double width,
    double height,
    double radius,
  ) => FadeTransition(
    opacity: opacity,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: IqColors.brandSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final width = this.width ?? 358;
    return Semantics(
      label: 'Loading',
      child: SkeletonPulse(
        builder: (context, opacity) => switch (kind) {
          IqSkeletonKind.ticket => _ticket(opacity, width),
          IqSkeletonKind.row => _row(opacity, width),
          IqSkeletonKind.line => _bar(opacity, width, 14, 7),
        },
      ),
    );
  }

  Widget _ticket(Animation<double> opacity, double width) {
    final stub = width - 358;
    return Container(
      width: width,
      height: 136,
      decoration: BoxDecoration(
        color: IqColors.tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _bar(opacity, 26, 26, 13),
                    const SizedBox(width: IqSpace.s2),
                    _bar(opacity, 120, 12, 6),
                  ],
                ),
                const SizedBox(height: IqSpace.s2),
                _bar(opacity, 218, 14, 9),
                const SizedBox(height: IqSpace.s2),
                _bar(opacity, 160, 14, 9),
                const SizedBox(height: IqSpace.s2),
                _bar(opacity, 113, 28, 14),
              ],
            ),
          ),
          Positioned(
            left: 260 + stub,
            top: 28,
            child: _bar(opacity, 87, 10, 5),
          ),
          Positioned(
            left: 260 + stub,
            top: 44,
            child: _bar(opacity, 79, 16, 6),
          ),
          Positioned(
            left: 256 + stub,
            top: 96,
            child: _bar(opacity, 83, 16, 6),
          ),
          Positioned(
            left: 245.5 + stub,
            top: 13,
            height: 110,
            width: 1,
            child: IqPerforation(
              color: IqColors.brand.withValues(alpha: 0.2),
              thickness: 1,
              dash: 3,
              gap: 4,
              roundCap: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Animation<double> opacity, double width) => Container(
    width: width,
    height: 64,
    color: IqColors.card,
    padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
    child: Row(
      children: [
        _bar(opacity, 40, 40, 12),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(opacity, 180, 14, 7),
              const SizedBox(height: IqSpace.s2),
              _bar(opacity, 120, 10, 5),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The skeleton pulse for [builder] (spec 5.15): the beat of the screen's
/// PulseScope, or a clock of its own outside one, behind a repaint boundary
/// so only the bars repaint; still at 1 under reduced motion.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.builder});

  final Widget Function(BuildContext context, Animation<double> opacity)
  builder;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;
  SkeletonBeat? _beat;
  Animation<double> _opacity = kAlwaysCompleteAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _beat?.leave();
      _beat = null;
      _own?.stop();
      _opacity = kAlwaysCompleteAnimation;
      return;
    }
    if (_beat != null || (_own?.isAnimating ?? false)) return;
    final beat = _beat = PulseScope.joinSkeletonBeat(context);
    if (beat != null) {
      _opacity = beat.opacity;
      return;
    }
    final own = _own ??= AnimationController(
      vsync: this,
      duration: IqSkeleton.pulse,
    );
    _opacity = SkeletonBeat.on(own);
    own.repeat();
  }

  @override
  void dispose() {
    _beat?.leave();
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: widget.builder(context, _opacity));
}
