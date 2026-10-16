import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Plays [IqHaptics.edge] once when a drag pushes a list past its end, on
/// clamping (Android) and bouncing (iOS) physics alike. Only the far end: the
/// start is where Discover pulls to refresh, with its own click. A flick that
/// coasts into the end stays quiet, and so do lists too short to scroll and
/// wheels (they tick on their own).
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
    } else if (_armed &&
        metrics.maxScrollExtent > metrics.minScrollExtent &&
        _pushedPastEnd(n)) {
      _armed = false;
      IqHaptics.edge.play();
    }
    return false;
  }

  static bool _pushedPastEnd(ScrollNotification n) {
    if (n is OverscrollNotification) {
      return n.dragDetails != null && n.overscroll > 0;
    }
    if (n is ScrollUpdateNotification && n.dragDetails != null) {
      return n.metrics.pixels > n.metrics.maxScrollExtent;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      );
}
