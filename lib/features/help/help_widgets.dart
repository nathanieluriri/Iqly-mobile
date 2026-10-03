import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../theme/theme.dart';
import '../../ui/tilt.dart';

/// Support typing: the Support bubble's sticker and name over a small
/// bubble whose three dots bob 4 px in a 600 ms loop (MOTION-SPEC §5.30,
/// Figma 168:1080). Figma has no component for it, so it borrows the
/// Exp/ChatBubble Support shape. It holds the screen's pulse first of all
/// claimants; without the grant, and under reduced motion, the dots stand
/// still.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key, this.name = 'iQLY support'});

  final String name;

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin, PulseLoop {
  @override
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: IqDurations.typingDots,
  );

  @override
  PulsePriority get pulsePriority => PulsePriority.typing;

  @override
  bool get wantsPulse => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPulse();
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(IqRadius.xl2);
    return Semantics(
      label: '${widget.name} is typing',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SupportName(name: widget.name),
            const SizedBox(height: IqSpace.s1p5),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: IqSpace.s4,
                vertical: IqSpace.s4,
              ),
              decoration: BoxDecoration(
                color: IqColors.card,
                border: Border.all(color: IqColors.brandLine2),
                borderRadius: const BorderRadius.only(
                  topLeft: r,
                  topRight: r,
                  bottomLeft: Radius.circular(4),
                  bottomRight: r,
                ),
              ),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: IqSpace.s1p5),
                        Transform.translate(
                          offset: Offset(0, _bob(i)),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: IqColors.fg3,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Each dot rises 4 px and settles once a loop, a third of a beat after
  /// the one before it.
  double _bob(int dot) {
    if (!pulsing) return 0;
    final phase = (pulse.value - dot / 3) % 1;
    return -IqTravel.nudge * math.max(0, math.sin(phase * 2 * math.pi));
  }
}

/// The tilted iQ sticker and "iQLY support", as Exp/ChatBubble Support draws
/// them above its bubble.
class SupportName extends StatelessWidget {
  const SupportName({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IqTilt(
          degrees: 6,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: IqColors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              'iQ',
              style: IqText.label.copyWith(color: IqColors.brand),
            ),
          ),
        ),
        const SizedBox(width: IqSpace.s2),
        Text(name, style: IqText.smallStrong.copyWith(color: IqColors.fg)),
      ],
    );
  }
}

/// Keeps [child]'s place empty for [delay], then builds it, so a part that
/// plays its own entrance (a chat bubble) starts on its beat. [standIn] is
/// the same part without its entrance, drawn see-through until then.
class Later extends StatefulWidget {
  const Later({
    super.key,
    required this.delay,
    required this.standIn,
    required this.child,
  });

  final Duration delay;
  final Widget standIn;
  final Widget child;

  @override
  State<Later> createState() => _LaterState();
}

class _LaterState extends State<Later> {
  Timer? _wait;
  bool _due = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _due = true;
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) setState(() => _due = true);
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_due) {
      return KeyedSubtree(key: const ValueKey(true), child: widget.child);
    }
    return KeyedSubtree(
      key: const ValueKey(false),
      child: Opacity(opacity: 0, child: widget.standIn),
    );
  }
}
