import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Plays [IqHaptics.edge] once when a drag pushes a list past either end, on
/// clamping (Android) and bouncing (iOS) physics alike, except the start of
/// a list under [PullsToRefresh], where the pull has its own click. A flick
/// that coasts into an end stays quiet, and so do lists too short to scroll
/// and wheels (they tick on their own).
class EdgeHaptics extends StatefulWidget {
  const EdgeHaptics({super.key, required this.child});

  final Widget child;

  @override
  State<EdgeHaptics> createState() => _EdgeHapticsState();
}

class _EdgeHapticsState extends State<EdgeHaptics> {
  bool _armed = false;

  bool _onScroll(ScrollNotification n) {
    final metrics = n.metrics;
    if (metrics is FixedExtentMetrics) return false;
    if (n is ScrollStartNotification) {
      _armed = n.dragDetails != null;
    } else if (n is ScrollEndNotification) {
      _armed = false;
    } else if (_armed && metrics.maxScrollExtent > metrics.minScrollExtent) {
      final end = _pushedPast(n);
      if (end == _End.far || (end == _End.start && !_pullsToRefresh(n))) {
        _armed = false;
        IqHaptics.edge.play();
      }
    }
    return false;
  }

  static _End? _pushedPast(ScrollNotification n) {
    if (n is OverscrollNotification) {
      if (n.dragDetails == null || n.overscroll == 0) return null;
      return n.overscroll > 0 ? _End.far : _End.start;
    }
    if (n is ScrollUpdateNotification && n.dragDetails != null) {
      if (n.metrics.pixels > n.metrics.maxScrollExtent) return _End.far;
      if (n.metrics.pixels < n.metrics.minScrollExtent) return _End.start;
    }
    return null;
  }

  static bool _pullsToRefresh(ScrollNotification n) =>
      n.metrics.axis == Axis.vertical &&
      n.context?.findAncestorWidgetOfExactType<PullsToRefresh>() != null;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      );
}

enum _End { start, far }

/// Marks a vertical list whose start pulls to refresh, so [EdgeHaptics]
/// leaves that end to the pull's own click.
class PullsToRefresh extends StatelessWidget {
  const PullsToRefresh({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
