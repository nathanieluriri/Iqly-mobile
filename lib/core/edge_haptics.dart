import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Plays [IqHaptics.edge] once on the frame a scroll the person drives (a
/// drag, or the fling it lets go into) reaches the top or bottom of a list,
/// on clamping (Android) and bouncing (iOS) physics alike. Pushing on past
/// the end plays nothing, and the end plays again only once the list has
/// left it. The start of a list under [PullsToRefresh] is left to the
/// pull's own click. Lists too short to scroll, programmatic scrolls and
/// wheels (they tick on their own) stay quiet.
class EdgeHaptics extends StatefulWidget {
  const EdgeHaptics({super.key, required this.child});

  final Widget child;

  @override
  State<EdgeHaptics> createState() => _EdgeHapticsState();
}

class _EdgeHapticsState extends State<EdgeHaptics> {
  // Keyed by each scrollable's context, since nested lists report here too.
  final _at = <BuildContext, _End?>{};

  bool _onScroll(ScrollNotification n) {
    final metrics = n.metrics;
    final key = n.context;
    if (metrics is FixedExtentMetrics || key == null) return false;
    if (n is ScrollStartNotification) {
      if (n.dragDetails != null) {
        _at[key] = _edgeOf(metrics);
      } else {
        _at.remove(key);
      }
    } else if (n is ScrollEndNotification) {
      _at.remove(key);
    } else if (n is ScrollUpdateNotification && _at.containsKey(key)) {
      final was = _at[key];
      final now = _edgeOf(metrics);
      _at[key] = now;
      if (now == null || now == was) return false;
      if (metrics.maxScrollExtent <= metrics.minScrollExtent) return false;
      if (now == _End.start && _pullsToRefresh(n)) return false;
      IqHaptics.edge.play();
    }
    return false;
  }

  static _End? _edgeOf(ScrollMetrics m) {
    const tolerance = 0.5;
    if (m.pixels >= m.maxScrollExtent - tolerance) return _End.far;
    if (m.pixels <= m.minScrollExtent + tolerance) return _End.start;
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
