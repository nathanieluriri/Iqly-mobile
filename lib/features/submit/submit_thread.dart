import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../theme/theme.dart';
import '../../ui/icon.dart';
import '../../ui/progress_thread.dart';
import '../../ui/vector.dart';

/// What the pinned thread says: an Exp/ProgressThread state and its words.
class ThreadLook {
  const ThreadLook.progress(this.text, this.count)
    : state = IqProgressThreadState.progress;
  const ThreadLook.ready(this.text)
    : state = IqProgressThreadState.ready,
      count = '';
  const ThreadLook.error(this.text, this.count)
    : state = IqProgressThreadState.error;

  final IqProgressThreadState state;
  final String text;
  final String count;

  /// Only Ready runs the full rule: 34:24 overrides the Error rule to the
  /// progress length (an answer still too short is not finished).
  bool get full => state == IqProgressThreadState.ready;

  Color get ink => switch (state) {
    IqProgressThreadState.progress => IqColors.fg,
    IqProgressThreadState.ready => IqColors.ok,
    IqProgressThreadState.error => IqColors.errStrong,
  };

  Color get rule => switch (state) {
    IqProgressThreadState.progress => IqColors.accent,
    IqProgressThreadState.ready => IqColors.ok,
    IqProgressThreadState.error => IqColors.err,
  };
}

/// The Exp/ProgressThread pinned under the Submit top bar (34:24, 34:121,
/// 34:186), built from the component's vectors and tokens because it moves
/// (MOTION-SPEC §5.26): on a state change the rule runs between half and
/// full over 240 ms ease-out while its colour and the icon cross over 160;
/// the words and the count roll. Ready on arrival draws the full rule left
/// to right (240). Reduced motion: the new state at once.
class SubmitThread extends StatefulWidget {
  const SubmitThread({super.key, required this.look});

  final ThreadLook look;

  @override
  State<SubmitThread> createState() => _SubmitThreadState();
}

class _SubmitThreadState extends State<SubmitThread>
    with SingleTickerProviderStateMixin {
  late final AnimationController _change = AnimationController(
    vsync: this,
    duration: IqDurations.mark,
  );
  late final Animation<double> _length = _change.drive(
    CurveTween(curve: IqCurves.easeOut),
  );
  late final Animation<double> _ink = _change.drive(
    CurveTween(
      curve: Interval(
        0,
        IqDurations.tick.inMicroseconds / IqDurations.mark.inMicroseconds,
        curve: IqCurves.easeOut,
      ),
    ),
  );

  ThreadLook? _from;
  double _fromLength = 0;
  bool _started = false;

  double _lengthOf(ThreadLook look) => look.full ? 1 : .5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.look.full && !MediaQuery.disableAnimationsOf(context)) {
      _fromLength = 0;
      _change.forward(from: 0);
    } else {
      _change.value = 1;
    }
  }

  @override
  void didUpdateWidget(SubmitThread old) {
    super.didUpdateWidget(old);
    if (old.look.state == widget.look.state) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _from = null;
      _change.value = 1;
      return;
    }
    _fromLength = _shownLength(old.look);
    _from = old.look;
    _change.forward(from: 0);
  }

  double _shownLength(ThreadLook look) {
    if (!_change.isAnimating) return _lengthOf(look);
    final to = _lengthOf(look);
    return _fromLength + (to - _fromLength) * _length.value;
  }

  @override
  void dispose() {
    _change.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final duration = motion(context, IqDurations.tick);
    final ready = look.state == IqProgressThreadState.ready;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 18,
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: IqCurves.easeOut,
                  switchOutCurve: IqCurves.easeOut,
                  child: KeyedSubtree(
                    key: ValueKey(look.state),
                    child: switch (look.state) {
                      IqProgressThreadState.progress => const SizedBox.shrink(),
                      IqProgressThreadState.ready => const IqIcon(
                        IqIcons.success,
                        size: 18,
                        color: IqColors.ok,
                      ),
                      IqProgressThreadState.error => const IqIcon(
                        IqIcons.error,
                        size: 18,
                        color: IqColors.err,
                      ),
                    },
                  ),
                ),
              ),
              const SizedBox(width: IqSpace.s1p5),
              Expanded(
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: look.ink),
                  duration: duration,
                  curve: IqCurves.easeOut,
                  builder: (context, ink, _) => RollingText(
                    look.text,
                    style: IqText.smallStrong.copyWith(color: ink),
                  ),
                ),
              ),
              const SizedBox(width: IqSpace.s2),
              ExcludeSemantics(
                excluding: ready,
                child: AnimatedOpacity(
                  opacity: ready ? 0 : 1,
                  duration: duration,
                  curve: ready ? IqCurves.easeIn : IqCurves.easeOut,
                  child: RollingText(
                    (ready ? _from?.count ?? '' : look.count).toUpperCase(),
                    style: IqText.mono.copyWith(color: IqColors.fg2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: IqSpace.s2),
          SizedBox(
            height: 6,
            child: LayoutBuilder(
              builder: (context, box) => AnimatedBuilder(
                animation: _change,
                builder: (context, _) => _rule(box.maxWidth),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rule(double width) {
    final look = widget.look;
    final from = _from;
    final settled = !_change.isAnimating;
    final to = _lengthOf(look);
    final length = settled
        ? to
        : _fromLength + (to - _fromLength) * _length.value;
    final ink = settled || from == null ? 1.0 : _ink.value;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 3,
          height: 1,
          child: ColoredBox(color: IqColors.line),
        ),
        if (!settled && from != null) _brush(from, width, length, 1 - ink),
        _brush(look, width, settled ? 1 : length, ink),
      ],
    );
  }

  Widget _brush(ThreadLook look, double width, double reveal, double opacity) {
    final Widget vector;
    if (look.full) {
      vector = Positioned(
        left: 0,
        width: width,
        top: 1.02,
        height: 3.88,
        child: IqVector(
          'assets/vectors/progress-thread-ready.svg',
          color: look.rule,
        ),
      );
    } else {
      vector = Positioned(
        left: -1.66,
        top: 1.25,
        width: width * 181.25 / 358,
        height: 3.65,
        child: IqVector(
          'assets/vectors/progress-thread-progress.svg',
          color: look.rule,
        ),
      );
    }
    return Positioned.fill(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: ClipRect(
          clipper: _RuleClip(reveal),
          child: Stack(clipBehavior: Clip.none, children: [vector]),
        ),
      ),
    );
  }
}

/// Shows the rule from its start to [reveal] of the width.
class _RuleClip extends CustomClipper<Rect> {
  const _RuleClip(this.reveal);

  final double reveal;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    -IqSpace.s2,
    -size.height,
    size.width * reveal.clamp(0.0, 1.0),
    size.height * 2,
  );

  @override
  bool shouldReclip(_RuleClip old) => old.reveal != reveal;
}
