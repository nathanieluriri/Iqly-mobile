import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'vector.dart';

enum IqProgressThreadState { progress, ready, error }

/// Exp/ProgressThread: one line of plain words and a count over a rule, a
/// half-length orange brush while in progress, full green when ready (count
/// hidden), full red on an error. It judges the long text area; short
/// fields validate inline.
///
/// Motion (spec 5.26, build extension): a state change grows or shortens
/// the rule over 240 ms ease-out as its colour crosses in 160, the words and
/// the count roll, and the status icon pops in from .6 (220) or fades out
/// (150). Ready on arrival draws its line left to right, 240. Under reduced
/// motion every change lands at once.
///
/// Note over Figma: words too long for the line wrap to a second line; the
/// master is one line.
class IqProgressThread extends StatefulWidget {
  const IqProgressThread({
    super.key,
    this.status = 'Account number next',
    this.count = '1 OF 2',
    this.readyText = 'Ready to save',
    this.errorText = 'Fix the account number',
    this.state = IqProgressThreadState.progress,
  });

  final String status;
  final String count;
  final String readyText;
  final String errorText;
  final IqProgressThreadState state;

  @override
  State<IqProgressThread> createState() => _IqProgressThreadState();
}

class _IqProgressThreadState extends State<IqProgressThread>
    with SingleTickerProviderStateMixin {
  /// The orange brush runs 181.25 of the 358 rule.
  static const double _half = 181.25 / 358;

  late final AnimationController _change = AnimationController(
    vsync: this,
    duration: IqDurations.mark,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
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
  IqProgressThreadState? _from;
  double _fromLength = 1;
  bool _arrived = false;

  static double _lengthOf(IqProgressThreadState state) =>
      state == IqProgressThreadState.progress ? _half : 1;

  double get _shownLength =>
      lerpDouble(_fromLength, _lengthOf(widget.state), _length.value)!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrived) return;
    _arrived = true;
    if (widget.state == IqProgressThreadState.ready &&
        !MediaQuery.disableAnimationsOf(context)) {
      _fromLength = 0;
      _change.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(IqProgressThread old) {
    super.didUpdateWidget(old);
    if (old.state == widget.state) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _from = null;
      _change.value = 1;
      return;
    }
    _fromLength = lerpDouble(_fromLength, _lengthOf(old.state), _length.value)!;
    _from = old.state;
    _change.forward(from: 0);
  }

  @override
  void dispose() {
    _change.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final state = widget.state;
    final (text, ink, icon, iconInk) = switch (state) {
      IqProgressThreadState.progress => (
        widget.status,
        IqColors.fg,
        null,
        null,
      ),
      IqProgressThreadState.ready => (
        widget.readyText,
        IqColors.ok,
        IqIcons.success,
        IqColors.ok,
      ),
      IqProgressThreadState.error => (
        widget.errorText,
        IqColors.errStrong,
        IqIcons.error,
        IqColors.err,
      ),
    };
    final showCount = state != IqProgressThreadState.ready;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox.square(
              dimension: 18,
              child: AnimatedSwitcher(
                duration: motion(context, IqDurations.appear),
                reverseDuration: motion(context, IqDurations.crossfade),
                switchInCurve: IqCurves.easeOut,
                switchOutCurve: IqCurves.easeOut,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation.drive(
                    Tween<double>(begin: IqScale.pop, end: 1),
                  ),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: icon == null
                    ? const SizedBox.shrink()
                    : IqIcon(
                        key: ValueKey(icon),
                        icon,
                        size: 18,
                        color: iconInk!,
                      ),
              ),
            ),
            const SizedBox(width: IqSpace.s1p5),
            Expanded(
              child: _Words(
                text,
                style: IqText.smallStrong.copyWith(color: ink),
                reduced: reduced,
              ),
            ),
            AnimatedSwitcher(
              duration: motion(context, IqDurations.crossfade),
              switchInCurve: IqCurves.easeOut,
              switchOutCurve: IqCurves.easeOut,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerRight,
                children: [...previous, ?current],
              ),
              child: showCount
                  ? Row(
                      key: const ValueKey('count'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: IqSpace.s2),
                        RollingText(
                          widget.count.toUpperCase(),
                          style: IqText.mono.copyWith(color: IqColors.fg2),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: IqSpace.s2),
        SizedBox(
          height: 6,
          child: LayoutBuilder(
            builder: (context, box) => AnimatedBuilder(
              animation: _change,
              builder: (context, _) {
                final from = _change.isCompleted ? null : _from;
                final vectors = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (from != null)
                      _rule(from, box.maxWidth, opacity: 1 - _ink.value),
                    _rule(
                      state,
                      box.maxWidth,
                      opacity: from == null ? 1 : _ink.value,
                    ),
                  ],
                );
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
                    Positioned.fill(
                      child: _change.isCompleted
                          ? vectors
                          : ClipRect(
                              clipper: _RuleClip(box.maxWidth * _shownLength),
                              child: vectors,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _rule(
    IqProgressThreadState state,
    double width, {
    required double opacity,
  }) {
    final Widget vector = switch (state) {
      IqProgressThreadState.progress => const IqVector(
        'assets/vectors/progress-thread-progress.svg',
        color: IqColors.accent,
      ),
      IqProgressThreadState.ready => const IqVector(
        'assets/vectors/progress-thread-ready.svg',
        color: IqColors.ok,
      ),
      IqProgressThreadState.error => const IqVector(
        'assets/vectors/progress-thread-error.svg',
        color: IqColors.err,
      ),
    };
    final shown = opacity >= 1
        ? vector
        : Opacity(opacity: opacity, child: vector);
    return switch (state) {
      IqProgressThreadState.progress => Positioned(
        left: -1.66,
        top: 1.25,
        width: width * _half,
        height: 3.65,
        child: shown,
      ),
      IqProgressThreadState.ready => Positioned(
        left: 0,
        right: 0,
        top: 1.02,
        height: 3.88,
        child: shown,
      ),
      IqProgressThreadState.error => Positioned(
        left: 0,
        right: 0,
        top: 1.25,
        height: 3.65,
        child: shown,
      ),
    };
  }
}

/// The status words: they roll when they change and fit the line, and wrap
/// to a second line when they do not.
class _Words extends StatelessWidget {
  const _Words(this.text, {required this.style, required this.reduced});

  final String text;
  final TextStyle style;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final words = LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout(maxWidth: box.maxWidth);
        final fits = !painter.didExceedMaxLines;
        painter.dispose();
        if (fits) return RollingText(text, style: style);
        return Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
    if (reduced) return words;
    return AnimatedSize(
      duration: IqDurations.tick,
      curve: IqCurves.easeOut,
      alignment: AlignmentDirectional.topStart,
      child: words,
    );
  }
}

/// Shows the rule up to [right], with room above and below for the brush.
class _RuleClip extends CustomClipper<Rect> {
  const _RuleClip(this.right);

  final double right;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, -size.height, right, size.height * 2);

  @override
  bool shouldReclip(_RuleClip oldClipper) => oldClipper.right != right;
}
