import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';

enum IqToastKind { success, error }

/// Toast (DS 11:59): a short confirmation that rises above the bottom edge
/// and leaves on its own, success in the ok tones and error in the error
/// tones. Only one shows at a time; a new one replaces it. Never use it for
/// anything the person must act on.
///
/// Figma over DS: the Error message and icon take err-strong, as frame
/// 1284:90206 does; the DS err on err-soft is 3.9:1, under AA.
class IqToast extends StatelessWidget {
  const IqToast({
    super.key,
    required this.message,
    this.kind = IqToastKind.success,
  });

  final String message;
  final IqToastKind kind;

  static OverlayEntry? _current;

  /// Shows [message] over the current screen.
  static void show(
    BuildContext context,
    String message, {
    IqToastKind kind = IqToastKind.success,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _current?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _Rising(
        onDone: () {
          if (identical(_current, entry)) _current = null;
          entry.remove();
        },
        child: IqToast(message: message, kind: kind),
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final success = kind == IqToastKind.success;
    final ink = success ? IqColors.ok : IqColors.errStrong;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s4,
          vertical: IqSpace.s4,
        ),
        decoration: BoxDecoration(
          color: success ? IqColors.okSoft : IqColors.errSoft,
          borderRadius: BorderRadius.circular(IqRadius.lg),
          border: Border.all(color: success ? IqColors.okDot : IqColors.err),
          boxShadow: IqShadows.md,
        ),
        child: Row(
          children: [
            IqIcon(
              success ? IqIcons.check : IqIcons.info,
              size: 16,
              color: ink,
            ),
            const SizedBox(width: IqSpace.s2),
            Expanded(
              child: Text(message, style: IqText.small.copyWith(color: ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rises 8 into place over 220 ms, holds for [IqDurations.toast], then
/// fades back down over 220 ms: one timeline, so it ends with its page.
class _Rising extends StatefulWidget {
  const _Rising({required this.child, required this.onDone});

  final Widget child;
  final VoidCallback onDone;

  @override
  State<_Rising> createState() => _RisingState();
}

class _RisingState extends State<_Rising> with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: IqDurations.appear * 2 + IqDurations.toast,
  )..addStatusListener(_ended);

  void _ended(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onDone();
  }

  @override
  void initState() {
    super.initState();
    _life.forward();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  /// 0 to 1 over the rise, 1 through the hold, back to 0 over the fall.
  double get _shown {
    final edge =
        IqDurations.appear.inMicroseconds / _life.duration!.inMicroseconds;
    final t = _life.value;
    final raw = t < edge ? t / edge : (t > 1 - edge ? (1 - t) / edge : 1.0);
    return IqCurves.easeOut.transform(raw.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Positioned(
      left: IqSpace.s4,
      right: IqSpace.s4,
      bottom: bottom + IqSpace.s6 * 3,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _life,
          child: Material(type: MaterialType.transparency, child: widget.child),
          builder: (context, child) {
            final t = _shown;
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, reduced ? 0 : IqTravel.nudge * (1 - t)),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
