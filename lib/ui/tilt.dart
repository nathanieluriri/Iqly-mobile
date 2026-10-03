import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Rotates [child] by [degrees] (positive is clockwise) and takes the size
/// of the rotated bounding box, as Figma lays out a rotated layer in auto
/// layout. Used by the tilted stamps and stickers.
class IqTilt extends SingleChildRenderObjectWidget {
  const IqTilt({super.key, required this.degrees, super.child});

  final double degrees;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTilt(degrees * math.pi / 180);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTilt).angle = degrees * math.pi / 180;
  }
}

class _RenderTilt extends RenderProxyBox {
  _RenderTilt(this._angle);

  double _angle;
  set angle(double value) {
    if (value == _angle) return;
    _angle = value;
    markNeedsLayout();
  }

  Matrix4 get _transform {
    final c = child!.size;
    return Matrix4.translationValues(size.width / 2, size.height / 2, 0)
      ..multiply(Matrix4.rotationZ(_angle))
      ..multiply(Matrix4.translationValues(-c.width / 2, -c.height / 2, 0));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints.loosen(), parentUsesSize: true);
    final s = child.size;
    final cos = math.cos(_angle).abs();
    final sin = math.sin(_angle).abs();
    size = constraints.constrain(
      Size(s.width * cos + s.height * sin, s.width * sin + s.height * cos),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child!, offset),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => child!.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }
}
