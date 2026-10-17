import 'package:flutter/widgets.dart';

import 'motion.dart';

/// Plays [IqHaptics.edge] once on the frame a scroll the person drives (a
/// drag, or the fling it lets go into) reaches the top or bottom of a list,
/// on clamping (Android) and bouncing (iOS) physics alike. Pushing on past
/// the end plays nothing, and the end plays again only once the list has
/// left it. Reaching the top of a list under [PullsToRefresh] plays too and
/// is noted there, so a pull armed in the same gesture keeps quiet.
/// Lists too short to scroll, programmatic scrolls and wheels (they tick on
/// their own) stay quiet.
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
        _pull(n)?.reachedTop = false;
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
      if (now == _End.start) _pull(n)?.reachedTop = true;
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

  static PullGesture? _pull(ScrollNotification n) =>
      n.metrics.axis == Axis.vertical ? PullsToRefresh.of(n.context!) : null;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      );
}

enum _End { start, far }

/// What [EdgeHaptics] noted of the drag in progress on a list that pulls to
/// refresh.
class PullGesture {
  /// The drag (or its fling) reached the top and played the edge stop, so
  /// the pull's own click would be a second buzz for one gesture.
  bool reachedTop = false;
}

/// Marks a vertical list whose start pulls to refresh, and shares its
/// [PullGesture] between [EdgeHaptics] and the pull.
class PullsToRefresh extends StatefulWidget {
  const PullsToRefresh({super.key, required this.child});

  final Widget child;

  static PullGesture? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PullScope>()?.gesture;

  @override
  State<PullsToRefresh> createState() => _PullsToRefreshState();
}

class _PullsToRefreshState extends State<PullsToRefresh> {
  final _gesture = PullGesture();

  @override
  Widget build(BuildContext context) =>
      _PullScope(gesture: _gesture, child: widget.child);
}

class _PullScope extends InheritedWidget {
  const _PullScope({required this.gesture, required super.child});

  final PullGesture gesture;

  @override
  bool updateShouldNotify(_PullScope old) => gesture != old.gesture;
}
