import 'package:flutter/material.dart';

/// Tap target that reports its pressed state to [builder] so components can
/// draw their own Pressed variant. No Material ripple. Focusable, and Enter
/// or Space activates it like a tap.
class IqPressable extends StatefulWidget {
  const IqPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final bool enabled;
  final String? semanticLabel;
  final HitTestBehavior behavior;

  @override
  State<IqPressable> createState() => _IqPressableState();
}

class _IqPressableState extends State<IqPressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
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
          onTapDown: active ? (_) => _set(true) : null,
          onTapUp: active ? (_) => _set(false) : null,
          onTapCancel: active ? () => _set(false) : null,
          onTap: active ? widget.onTap : null,
          child: widget.builder(context, _pressed && active),
        ),
      ),
    );
  }
}
