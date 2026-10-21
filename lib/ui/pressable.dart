import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/motion.dart';

/// Tap target that reports its pressed state to [builder] so components can
/// draw their own Pressed variant. No Material ripple. A quick tap keeps the
/// press drawn for at least [IqDurations.pressHold] (in a scroll view the tap
/// reports down and up together) while [onTap] fires at once, with
/// [haptic] (a light tap unless the component asks for more, or null for
/// none). Focusable, and Enter or Space activates it like a tap.
///
/// With [tactile] the whole target sinks while held and springs back on
/// release, by [IqScale.pressShrink] points across its longer side; a
/// component that draws its own designed press scale turns it off. Figma
/// draws each Pressed variant at full size and the sink comes on top (the
/// owner's feel pass, 16 Oct), so the pressed goldens show it.
///
/// Holding it plays [IqHaptics.hold] and runs [onLongPress], or else shows
/// [hint] as a tooltip (icon-only controls pass their label, so a long
/// press says what an unlabelled icon does).
class IqPressable extends StatefulWidget {
  const IqPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.semanticLabel,
    this.semanticHint,
    this.hint,
    this.behavior = HitTestBehavior.opaque,
    this.haptic = IqHaptics.tap,
    this.tactile = true,
  });

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final String? semanticLabel;

  /// What a screen reader adds after the label, what activating it does.
  final String? semanticHint;
  final String? hint;
  final HitTestBehavior behavior;
  final IqHaptics? haptic;
  final bool tactile;

  @override
  State<IqPressable> createState() => _IqPressableState();
}

class _IqPressableState extends State<IqPressable>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _down = false;
  Timer? _hold;
  final _tooltip = GlobalKey<TooltipState>();
  // Below zero is the spring past rest on release.
  late final AnimationController _sink = AnimationController(
    vsync: this,
    value: 0,
    lowerBound: -1,
  );

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    if (!widget.tactile) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _sink.value = 0;
      return;
    }
    value
        ? _sink.animateTo(
            1,
            duration: IqDurations.press,
            curve: IqCurves.easeOut,
          )
        : _sink.animateTo(
            0,
            duration: IqDurations.appear,
            curve: IqCurves.stamp,
          );
  }

  void _press(TapDownDetails details) {
    _hold?.cancel();
    _hold = Timer(IqDurations.pressHold, () {
      _hold = null;
      if (!_down) _set(false);
    });
    _down = true;
    _set(true);
  }

  void _lift(TapUpDetails details) {
    _down = false;
    if (_hold == null) _set(false);
  }

  void _cancel() {
    _hold?.cancel();
    _hold = null;
    _down = false;
    _set(false);
  }

  void _tap() {
    widget.haptic?.play();
    widget.onTap?.call();
  }

  void _longPress() {
    _cancel();
    IqHaptics.hold.play();
    final action = widget.onLongPress;
    if (action != null) return action();
    _tooltip.currentState?.ensureTooltipVisible();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _sink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    final hint = widget.hint ?? '';
    final holdable = active && (widget.onLongPress != null || hint.isNotEmpty);
    Widget face = widget.builder(context, _pressed && active);
    if (widget.tactile) face = _Sink(depth: _sink, child: face);
    // Wrapped while off too: a face that remounts loses its own motion.
    if (hint.isNotEmpty &&
        widget.onLongPress == null &&
        Overlay.maybeOf(context) != null) {
      face = Tooltip(
        key: _tooltip,
        message: hint,
        triggerMode: TooltipTriggerMode.manual,
        excludeFromSemantics: true,
        child: face,
      );
    }
    return Semantics(
      button: true,
      enabled: active,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      child: FocusableActionDetector(
        enabled: active,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        child: GestureDetector(
          behavior: widget.behavior,
          onTapDown: active ? _press : null,
          onTapUp: active ? _lift : null,
          onTapCancel: active ? _cancel : null,
          onTap: active ? _tap : null,
          onLongPress: holdable ? _longPress : null,
          child: face,
        ),
      ),
    );
  }
}

/// Scales its child about the centre by [depth] of the press sink, sized
/// from the child's own box so every target travels the same distance.
class _Sink extends SingleChildRenderObjectWidget {
  const _Sink({required this.depth, super.child});

  final Animation<double> depth;

  @override
  _RenderSink createRenderObject(BuildContext context) => _RenderSink(depth);

  @override
  void updateRenderObject(BuildContext context, _RenderSink renderObject) {
    renderObject.depth = depth;
  }
}

class _RenderSink extends RenderProxyBox {
  _RenderSink(this._depth);

  Animation<double> _depth;

  set depth(Animation<double> value) {
    if (identical(value, _depth)) return;
    if (attached) _depth.removeListener(markNeedsPaint);
    _depth = value;
    if (attached) _depth.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _depth.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _depth.removeListener(markNeedsPaint);
    super.detach();
  }

  double get _scale {
    final longest = math.max(size.width, size.height);
    if (longest <= 0) return 1;
    final full = (1 - IqScale.pressShrink / longest).clamp(
      IqScale.pressMin,
      IqScale.pressMax,
    );
    return 1 - (1 - full) * _depth.value;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final scale = _scale;
    if (scale == 1) {
      layer = null;
      return context.paintChild(child, offset);
    }
    final centre = size.center(Offset.zero);
    final transform = Matrix4.identity()
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
    layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is TransformLayer ? layer as TransformLayer : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final scale = _scale;
    final centre = size.center(Offset.zero);
    transform
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
  }
}

/// A text link or ghost under the finger (spec 5.1): [child] dims to .6
/// while [pressed], 100 ms down and 160 back, the same under reduced motion.
class PressDim extends StatelessWidget {
  const PressDim({super.key, required this.pressed, required this.child});

  final bool pressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: pressed ? IqOpacity.pressed : 1,
      duration: pressed ? IqDurations.dim : IqDurations.release,
      curve: IqCurves.easeOut,
      child: child,
    );
  }
}
