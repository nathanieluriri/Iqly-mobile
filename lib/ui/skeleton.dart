import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'perforation.dart';

enum IqSkeletonKind { ticket, row, line }

/// Exp/Skeleton: loading placeholders. Ticket mirrors the List TicketCard
/// (main bars, stub bars, perforation at 246), Row mirrors Exp/ListRow,
/// Line is one text line. Bars are brand at 10% and pulse together, 0.5 to
/// 1 to 0.5 over 900 ms; still at full under reduced motion. Screens show
/// it after [showAfter] of waiting and keep it at least [minVisible].
///
/// Figma over brief: the Ticket skeleton is a plain tint rectangle (radius 16), no notched silhouette.
/// Figma over brief: its perforation is brand 1 px, dash 3/4, at 20%.
class IqSkeleton extends StatefulWidget {
  const IqSkeleton({super.key, this.kind = IqSkeletonKind.ticket, this.width});

  final IqSkeletonKind kind;

  /// Defaults to the Figma 358.
  final double? width;

  static const Duration pulse = IqDurations.skeletonPulse;
  static const Duration showAfter = IqDurations.skeletonDelay;
  static const Duration minVisible = IqDurations.skeletonMin;

  @override
  State<IqSkeleton> createState() => _IqSkeletonState();
}

class _IqSkeletonState extends State<IqSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: IqSkeleton.pulse,
  );
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.5, end: 1), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1, end: 0.5), weight: 1),
  ]).chain(CurveTween(curve: IqCurves.easeInOut)).animate(_pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _bar(double width, double height, double radius) => FadeTransition(
    opacity: _opacity,
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
    final width = widget.width ?? 358;
    return Semantics(
      label: 'Loading',
      child: switch (widget.kind) {
        IqSkeletonKind.ticket => _ticket(width),
        IqSkeletonKind.row => _row(width),
        IqSkeletonKind.line => _bar(width, 14, 7),
      },
    );
  }

  Widget _ticket(double width) {
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
                    _bar(26, 26, 13),
                    const SizedBox(width: IqSpace.s2),
                    _bar(120, 12, 6),
                  ],
                ),
                const SizedBox(height: IqSpace.s2),
                _bar(218, 14, 9),
                const SizedBox(height: IqSpace.s2),
                _bar(160, 14, 9),
                const SizedBox(height: IqSpace.s2),
                _bar(113, 28, 14),
              ],
            ),
          ),
          Positioned(left: 260 + stub, top: 28, child: _bar(87, 10, 5)),
          Positioned(left: 260 + stub, top: 44, child: _bar(79, 16, 6)),
          Positioned(left: 256 + stub, top: 96, child: _bar(83, 16, 6)),
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

  Widget _row(double width) => Container(
    width: width,
    height: 64,
    color: IqColors.card,
    padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
    child: Row(
      children: [
        _bar(40, 40, 12),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(180, 14, 7),
              const SizedBox(height: IqSpace.s2),
              _bar(120, 10, 5),
            ],
          ),
        ),
      ],
    ),
  );
}
