import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'vector.dart';

enum IqPullIndicatorState { pull, refreshing, done }

/// Exp/PullIndicator: the row above the feed while the user pulls. Pull
/// fades in with the drag ([pullExtent], 0 to 1 over the first 64 px; null
/// shows it fully) and its arrow turns over once the pull is [armed] (160
/// ms). Refreshing turns the brush loop once per 900 ms until data lands
/// (still under reduced motion). Done draws its check (160 ms); the screen
/// holds it for [doneHold] and then collapses the row. The states crossfade
/// in place over 120 ms, so one indicator serves the whole refresh (spec
/// 4.6, 5.16).
///
/// Figma over brief: the Pull arrow and Done check are plain vectors, not brush icons; Done reads "UP TO DATE · <time>" in Color/ok.
/// Build extension: the armed arrow turn and the state crossfades.
class IqPullIndicator extends StatefulWidget {
  const IqPullIndicator({
    super.key,
    this.state = IqPullIndicatorState.pull,
    this.pullExtent,
    this.armed = false,
    this.pullLabel = 'Pull to refresh',
    this.refreshingLabel = 'Refreshing',
    this.doneLabel = 'Up to date · 9:41',
    this.width = 358,
  });

  final IqPullIndicatorState state;
  final double? pullExtent;

  /// The pull has gone far enough to refresh when let go.
  final bool armed;
  final String pullLabel;
  final String refreshingLabel;
  final String doneLabel;
  final double width;

  static const double height = 40;
  static const double fadeDistance = IqTravel.pullArm;
  static const Duration turn = IqDurations.refreshTurn;
  static const Duration doneHold = IqDurations.doneHold;

  @override
  State<IqPullIndicator> createState() => _IqPullIndicatorState();
}

class _IqPullIndicatorState extends State<IqPullIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: IqPullIndicator.turn,
  );
  late final AnimationController _arm = AnimationController(
    vsync: this,
    duration: IqDurations.tick,
    value: widget.armed ? 1 : 0,
  );
  late final Animation<double> _armTurn = _arm.drive(
    CurveTween(curve: IqCurves.easeInOut),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(IqPullIndicator old) {
    super.didUpdateWidget(old);
    if (old.armed != widget.armed) {
      if (_reduced) {
        _arm.value = 0;
      } else if (widget.armed) {
        _arm.forward();
      } else {
        _arm.reverse();
      }
    }
    _sync();
  }

  void _sync() {
    final spin = widget.state == IqPullIndicatorState.refreshing && !_reduced;
    if (spin && !_turn.isAnimating) {
      _turn.repeat();
    } else if (!spin) {
      _turn.stop();
    }
    if (_reduced) _arm.value = 0;
  }

  @override
  void dispose() {
    _turn.dispose();
    _arm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final (Widget mark, String label, Color ink) = switch (state) {
      IqPullIndicatorState.pull => (
        AnimatedBuilder(
          animation: _armTurn,
          child: _stroke(
            'pull-indicator-arrow',
            IqColors.brand,
            9,
            11.25,
            11,
            14,
          ),
          builder: (context, child) =>
              Transform.rotate(angle: math.pi * _armTurn.value, child: child),
        ),
        widget.pullLabel,
        IqColors.fg2,
      ),
      IqPullIndicatorState.refreshing => (
        RepaintBoundary(
          child: RotationTransition(
            turns: _turn,
            child: const IqIcon(
              IqIcons.refresh,
              size: 18,
              color: IqColors.brand,
            ),
          ),
        ),
        widget.refreshingLabel,
        IqColors.fg2,
      ),
      IqPullIndicatorState.done => (
        Wipe(
          duration: IqDurations.tick,
          child: _stroke(
            'pull-indicator-check',
            IqColors.ok,
            12,
            8.625,
            14,
            11,
          ),
        ),
        widget.doneLabel,
        IqColors.ok,
      ),
    };
    final row = SizedBox(
      width: widget.width,
      height: IqPullIndicator.height,
      child: AnimatedSwitcher(
        duration: motion(context, IqDurations.chain),
        switchInCurve: IqCurves.easeOut,
        switchOutCurve: IqCurves.easeOut,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [...previous, ?current],
        ),
        child: Row(
          key: ValueKey(state),
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
      ),
    );
    final extent = widget.pullExtent;
    // Always wrapped, so the crossfade survives the change of state.
    return Opacity(
      opacity: state != IqPullIndicatorState.pull || extent == null
          ? 1
          : (extent / IqPullIndicator.fadeDistance).clamp(0.0, 1.0),
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
