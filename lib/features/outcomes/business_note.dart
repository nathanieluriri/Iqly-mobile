import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../data/models.dart';
import '../../data/outcomes_data.dart';
import '../../theme/theme.dart';
import '../submissions/brief_art.dart';
import 'outcomes_state.dart';

/// The note's card bubble (193:9681): card fill, 1 line, radius 16, 12 by 14.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: IqSpace.s3),
      decoration: BoxDecoration(
        color: IqColors.card,
        border: Border.all(color: IqColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: IqText.body.copyWith(color: IqColors.fg)),
    );
  }
}

/// The business's note: who, the bubble and when (193:9681 brand-note),
/// on Results and on Submission detail.
class BusinessNoteView extends StatelessWidget {
  const BusinessNoteView({
    super.key,
    required this.note,
    required this.brief,
    required this.now,
  });

  final BusinessNote note;
  final Brief? brief;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: Row(
            children: [
              ClipOval(child: briefLogo(brief, size: 26)),
              const SizedBox(width: IqSpace.s2),
              Flexible(
                child: Text(
                  note.business,
                  style: IqText.smallStrong.copyWith(color: IqColors.fg),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: IqSpace.s2p5),
        _BubbleArrives(child: _Bubble(text: note.body)),
        const SizedBox(height: IqSpace.s2p5),
        Text(
          noteTime(note.sentAt, now),
          style: IqText.small.copyWith(color: IqColors.fg3),
        ),
      ],
    );
  }
}

/// The note bubble arrives like a support ChatBubble (MOTION-SPEC §5.30,
/// §5.33): from +200 it fades in and grows from .96 at its top left corner,
/// 220 ms ease-out. Reduced motion: it fades in over 150.
class _BubbleArrives extends StatefulWidget {
  const _BubbleArrives({required this.child});

  final Widget child;

  @override
  State<_BubbleArrives> createState() => _BubbleArrivesState();
}

class _BubbleArrivesState extends State<_BubbleArrives>
    with SingleTickerProviderStateMixin {
  static const _at = IqDurations.swap;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  Animation<double> _t = kAlwaysCompleteAnimation;
  bool _reduced = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _clock.duration = IqDurations.crossfade;
      _t = _clock.drive(CurveTween(curve: IqCurves.easeOut));
    } else {
      final total = _at + IqDurations.appear;
      _clock.duration = total;
      _t = _clock.drive(
        CurveTween(
          curve: Interval(
            _at.inMicroseconds / total.inMicroseconds,
            1,
            curve: IqCurves.easeOut,
          ),
        ),
      );
    }
    _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.scale(
          scale: _reduced ? 1 : IqScale.soft + (1 - IqScale.soft) * _t.value,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
    );
  }
}
