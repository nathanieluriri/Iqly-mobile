import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'vector.dart';

enum IqPullIndicatorState { pull, refreshing, done }

/// Exp/PullIndicator: the row above the feed while the user pulls. Pull
/// fades in with the drag ([pullExtent], 0 to 1 over the first 64 px; null
/// shows it fully). Refreshing turns the brush loop once per 900 ms until
/// data lands (still under reduced motion). Done shows the check; the
/// screen holds it for [doneHold] and then collapses the row.
///
/// Figma over brief: the Pull arrow and Done check are plain vectors, not brush icons; Done reads "UP TO DATE · <time>" in Color/ok.
class IqPullIndicator extends StatefulWidget {
  const IqPullIndicator({
    super.key,
    this.state = IqPullIndicatorState.pull,
    this.pullExtent,
    this.pullLabel = 'Pull to refresh',
    this.refreshingLabel = 'Refreshing',
    this.doneLabel = 'Up to date · 9:41',
    this.width = 358,
  });

  final IqPullIndicatorState state;
  final double? pullExtent;
  final String pullLabel;
  final String refreshingLabel;
  final String doneLabel;
  final double width;

  static const double height = 40;
  static const double fadeDistance = 64;
  static const Duration turn = Duration(milliseconds: 900);
  static const Duration doneHold = Duration(milliseconds: 800);

  @override
  State<IqPullIndicator> createState() => _IqPullIndicatorState();
}

class _IqPullIndicatorState extends State<IqPullIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: IqPullIndicator.turn,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(IqPullIndicator old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final spin =
        widget.state == IqPullIndicatorState.refreshing &&
        !MediaQuery.disableAnimationsOf(context);
    if (spin && !_turn.isAnimating) {
      _turn.repeat();
    } else if (!spin) {
      _turn.stop();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (Widget mark, String label, Color ink) = switch (widget.state) {
      IqPullIndicatorState.pull => (
        _stroke('pull-indicator-arrow', IqColors.brand, 9, 11.25, 11, 14),
        widget.pullLabel,
        IqColors.fg2,
      ),
      IqPullIndicatorState.refreshing => (
        RotationTransition(
          turns: _turn,
          child: const IqIcon(IqIcons.refresh, size: 18, color: IqColors.brand),
        ),
        widget.refreshingLabel,
        IqColors.fg2,
      ),
      IqPullIndicatorState.done => (
        _stroke('pull-indicator-check', IqColors.ok, 12, 8.625, 14, 11),
        widget.doneLabel,
        IqColors.ok,
      ),
    };
    final row = SizedBox(
      width: widget.width,
      height: IqPullIndicator.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          mark,
          const SizedBox(width: IqSpace.s2),
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: IqText.mono.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
    final extent = widget.pullExtent;
    if (widget.state != IqPullIndicatorState.pull || extent == null) {
      return row;
    }
    return Opacity(
      opacity: (extent / IqPullIndicator.fadeDistance).clamp(0.0, 1.0),
      child: row,
    );
  }

  /// The stroked vector's export is wider than its layer by the stroke
  /// overhang, so it is centred over the layer box.
  Widget _stroke(
    String name,
    Color color,
    double w,
    double h,
    double svgW,
    double svgH,
  ) {
    return SizedBox(
      width: w,
      height: h,
      child: OverflowBox(
        maxWidth: svgW,
        maxHeight: svgH,
        child: IqVector(
          'assets/vectors/$name.svg',
          color: color,
          width: svgW,
          height: svgH,
        ),
      ),
    );
  }
}
