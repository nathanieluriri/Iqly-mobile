import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/responsive.dart';
import '../theme/theme.dart';
import 'icon.dart';

enum IqToastKind { success, error, hint }

/// Toast (DS 11:59): a short confirmation that rises above the bottom edge
/// and leaves on its own, success in the ok tones and error in the error
/// tones. [IqToastKind.hint] is the app's own, not in the DS: a neutral
/// pointer (how to use a control) on the card with the info icon, with no
/// success check. Only one shows at a time; a new one replaces it. Never use it for
/// anything the person must act on.
///
/// Figma over DS: the Error message and icon take err-strong, as frame
/// 1284:90206 does; the DS err on err-soft is 3.9:1, under AA. The DS sets
/// the message in Body/Small strong, a web style; the Mob kit's nearest is
/// Mob/Small strong.
///
/// It floats 24 above the screen's [IqToastFloor], or above the home
/// indicator on a screen without one, and above the keyboard while it is up.
class IqToast extends StatelessWidget {
  const IqToast({
    super.key,
    required this.message,
    this.kind = IqToastKind.success,
  });

  final String message;
  final IqToastKind kind;

  static OverlayEntry? _current;

  /// Shows [message] over the current screen for [hold].
  static void show(
    BuildContext context,
    String message, {
    IqToastKind kind = IqToastKind.success,
    Duration hold = IqDurations.toast,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final floor = _IqToastFloorState.topFor(context);
    _current?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _Rising(
        floor: floor,
        hold: hold,
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
    final (ink, fill, edge, icon) = switch (kind) {
      IqToastKind.success => (
        IqColors.ok,
        IqColors.okSoft,
        IqColors.okDot,
        IqIcons.check,
      ),
      IqToastKind.error => (
        IqColors.errStrong,
        IqColors.errSoft,
        IqColors.err,
        IqIcons.info,
      ),
      IqToastKind.hint => (
        IqColors.fg2,
        IqColors.card,
        IqColors.line,
        IqIcons.info,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s4,
          vertical: IqSpace.s4,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(IqRadius.lg),
          border: Border.all(color: edge),
          boxShadow: IqShadows.md,
        ),
        child: Row(
          children: [
            IqIcon(icon, size: 16, color: ink),
            const SizedBox(width: IqSpace.s2),
            Expanded(
              child: Text(
                message,
                style: IqText.smallStrong.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rises 8 into place over 220 ms, holds for [hold], then
/// fades back down over 220 ms: one timeline, so it ends with its page.
class _Rising extends StatefulWidget {
  const _Rising({
    required this.child,
    required this.onDone,
    required this.hold,
    this.floor,
  });

  final Widget child;
  final Duration hold;
  final VoidCallback onDone;

  /// The top of the screen's bottom chrome, from the top of the screen.
  final double? floor;

  @override
  State<_Rising> createState() => _RisingState();
}

class _RisingState extends State<_Rising> with SingleTickerProviderStateMixin {
  // Preserve: reduced motion speeds controllers up, and the hold must last.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: IqDurations.appear * 2 + widget.hold,
    animationBehavior: AnimationBehavior.preserve,
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
    final floor = widget.floor;
    final rest = floor == null
        ? MediaQuery.viewPaddingOf(context).bottom
        : MediaQuery.sizeOf(context).height - floor;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: math.max(rest, keyboard) + IqSpace.s6,
      child: IgnorePointer(
        child: CenteredContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: IqSpace.s4),
            child: AnimatedBuilder(
              animation: _life,
              child: Material(
                type: MaterialType.transparency,
                child: widget.child,
              ),
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
        ),
      ),
    );
  }
}

/// Marks [child] as its screen's bottom chrome (a footer of buttons, the
/// dock): a toast shown from the same route floats 24 above it, as frame
/// 1284:90206 sets it over the step's Finish. A route inside the tab shell
/// falls back to the shell's dock.
class IqToastFloor extends StatefulWidget {
  const IqToastFloor({super.key, required this.child});

  final Widget child;

  @override
  State<IqToastFloor> createState() => _IqToastFloorState();
}

class _IqToastFloorState extends State<IqToastFloor> {
  static final _floors = <Route<Object?>, _IqToastFloorState>{};
  Route<Object?>? _route;

  /// The top of the floor on [context]'s route, or on the route that holds
  /// its navigator, from the top of the screen.
  static double? topFor(BuildContext context) {
    var route = ModalRoute.of(context);
    while (route != null) {
      final box = _floors[route]?.context.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        return box.localToGlobal(Offset.zero).dy;
      }
      final holder = route.navigator?.context;
      route = holder == null ? null : ModalRoute.of(holder);
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    _leave();
    _route = route;
    if (route != null) _floors[route] = this;
  }

  void _leave() {
    if (identical(_floors[_route], this)) _floors.remove(_route);
  }

  @override
  void dispose() {
    _leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
