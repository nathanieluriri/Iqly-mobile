import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The pull to refresh slot at the top of the feed (spec 4.6, 5.16): one
/// child that draws in the gap a pull opens above the list, bottom aligned
/// so it travels with the finger, and holds [extent] of the list while the
/// feed refreshes. When [steady] is on, a change of [extent] moves the scroll
/// position with it, so nothing on screen jumps (the slot taking over a
/// pull's overscroll, or closing while scrolled away); otherwise the list
/// below moves with the slot.
class RefreshSlot extends SingleChildRenderObjectWidget {
  const RefreshSlot({
    super.key,
    required this.extent,
    this.steady = false,
    required super.child,
  });

  final double extent;
  final bool steady;

  @override
  RenderRefreshSlot createRenderObject(BuildContext context) =>
      RenderRefreshSlot(extent: extent, steady: steady);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderRefreshSlot renderObject,
  ) {
    renderObject
      ..extent = extent
      ..steady = steady;
  }
}

/// The render object of a [RefreshSlot].
class RenderRefreshSlot extends RenderSliver
    with RenderObjectWithChildMixin<RenderBox> {
  RenderRefreshSlot({required double extent, required bool steady})
    : _extent = extent,
      _laidOut = extent {
    _steady = steady;
  }

  double _extent;
  set extent(double value) {
    if (value == _extent) return;
    _extent = value;
    markNeedsLayout();
  }

  bool _steady = false;
  set steady(bool value) {
    if (value == _steady) return;
    _steady = value;
    markNeedsLayout();
  }

  /// The extent the last layout reported, to steady the scroll against.
  double _laidOut;

  @override
  void performLayout() {
    final constraints = this.constraints;
    if (_steady && _extent != _laidOut) {
      final correction = _extent - _laidOut;
      _laidOut = _extent;
      geometry = SliverGeometry(scrollOffsetCorrection: correction);
      return;
    }
    _laidOut = _extent;
    final overscroll = math.max(0.0, -constraints.overlap);
    final height = _extent + overscroll;
    if (height <= 0 || child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    child!.layout(
      constraints.asBoxConstraints(minExtent: height, maxExtent: height),
      parentUsesSize: true,
    );
    final paintExtent = math.min(
      math.max(0.0, height - constraints.scrollOffset),
      constraints.remainingPaintExtent,
    );
    geometry = SliverGeometry(
      scrollExtent: _extent,
      paintOrigin: -overscroll - constraints.scrollOffset,
      paintExtent: paintExtent,
      maxPaintExtent: height,
      layoutExtent: math.min(
        math.max(0.0, _extent - constraints.scrollOffset),
        paintExtent,
      ),
      hitTestExtent: 0,
      hasVisualOverflow: true,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final geometry = this.geometry;
    if (child == null || geometry == null || !geometry.visible) return;
    context.paintChild(child!, offset);
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {}
}

/// Paints [child] over the slivers after it without taking any of the
/// list's space or taps: the skeleton fading out over the arriving feed
/// (spec 5.15).
class SliverOverlay extends SingleChildRenderObjectWidget {
  const SliverOverlay({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSliverOverlay();
}

class _RenderSliverOverlay extends RenderSliverSingleBoxAdapter {
  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    child.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    final height = child.size.height;
    final paintExtent = calculatePaintOffset(constraints, from: 0, to: height);
    geometry = SliverGeometry(
      paintExtent: paintExtent,
      maxPaintExtent: height,
      hitTestExtent: 0,
      hasVisualOverflow: true,
    );
    setChildParentData(child, constraints, geometry!);
  }
}
