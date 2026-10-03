import 'dart:async';

import 'package:flutter/material.dart';

import '../core/motion.dart';

/// Tap target that reports its pressed state to [builder] so components can
/// draw their own Pressed variant. No Material ripple. A quick tap keeps the
/// press drawn for at least [IqDurations.pressHold] (in a scroll view the tap
/// reports down and up together) while [onTap] fires at once, with
/// [haptic]. Focusable, and Enter or Space activates it like a tap.
class IqPressable extends StatefulWidget {
  const IqPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.behavior = HitTestBehavior.opaque,
    this.haptic,
  });

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;
  final HitTestBehavior behavior;
  final IqHaptics? haptic;

  @override
  State<IqPressable> createState() => _IqPressableState();
}

class _IqPressableState extends State<IqPressable> {
  bool _pressed = false;
  bool _down = false;
  Timer? _hold;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
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

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return Semantics(
      button: true,
      enabled: active,
      label: widget.semanticLabel,
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
          child: widget.builder(context, _pressed && active),
        ),
      ),
    );
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
