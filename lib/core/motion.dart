import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The kit's error language, shared so every row fails the same way: the
/// ProofTile shake, the Highlight wipe, and a help line that rises into
/// place. Under reduced motion nothing moves; the error just appears.
abstract final class ErrorMotion {
  static const Duration shake = Duration(milliseconds: 240);
  static const Duration wipe = Duration(milliseconds: 240);
  static const Duration reveal = Duration(milliseconds: 160);
  static const double shakeDistance = 2;
  static const int shakeTimes = 3;
  static const double rise = 4;
}

/// The haptic that goes with a failed submit.
Future<void> errorHaptic() => HapticFeedback.mediumImpact();

/// Shakes [child] 2 px three times over 240 ms each time [trigger] changes
/// (a count of failed submits, say).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: ErrorMotion.shake,
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !_reduced) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          ErrorMotion.shakeDistance *
              math.sin(_shake.value * math.pi * 2 * ErrorMotion.shakeTimes),
          0,
        ),
        child: child,
      ),
    );
  }
}

/// Plays once when the widget first builds, unless motion is reduced.
mixin _PlayOnce<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  Duration get duration;

  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: duration,
  );
  late final CurvedAnimation progress = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOut,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
    } else {
      controller.forward();
    }
  }

  @override
  void dispose() {
    progress.dispose();
    controller.dispose();
    super.dispose();
  }
}

/// Wipes [child] in left to right, 240 ms ease-out, as the Highlight marker
/// does. Paints unclipped once it has landed.
class Wipe extends StatefulWidget {
  const Wipe({super.key, required this.child});

  final Widget child;

  @override
  State<Wipe> createState() => _WipeState();
}

class _WipeState extends State<Wipe>
    with SingleTickerProviderStateMixin, _PlayOnce {
  @override
  Duration get duration => ErrorMotion.wipe;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      child: widget.child,
      builder: (context, child) => ClipRect(
        clipper: _WipeClipper(progress.value),
        clipBehavior: controller.isCompleted ? Clip.none : Clip.hardEdge,
        child: child,
      ),
    );
  }
}

class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper(this.reveal);

  final double reveal;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, -size.height, size.width * reveal, size.height * 3);

  @override
  bool shouldReclip(_WipeClipper oldClipper) => oldClipper.reveal != reveal;
}

/// Fades [child] in as it rises 4 px into place, 160 ms ease-out. Screen
/// readers get it from the first frame.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child});

  final Widget child;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal>
    with SingleTickerProviderStateMixin, _PlayOnce {
  @override
  Duration get duration => ErrorMotion.reveal;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: progress.value,
        alwaysIncludeSemantics: true,
        child: Transform.translate(
          offset: Offset(0, ErrorMotion.rise * (1 - progress.value)),
          child: child,
        ),
      ),
    );
  }
}
