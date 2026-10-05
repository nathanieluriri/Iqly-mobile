import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/motion.dart';
import '../../data/submit_data.dart';
import '../../theme/theme.dart';

/// How the answer area judges its text, which the pinned thread mirrors.
enum AnswerLook { neutral, error, ready }

/// The 34:24 text area: a plain frame, not an Exp/Field (the long answer
/// grows past one line): "Your answer" in brand Mob/Label, the answer in Mob/Body,
/// a 2 px rule and the character count. The rule is err while the answer is
/// short and ok once it is ready, crossing over 160 ms (MOTION-SPEC §7.4);
/// before any answer it is line2, brand while focused (the B10 focus look).
class AnswerArea extends StatefulWidget {
  const AnswerArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.look,
    required this.length,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final AnswerLook look;
  final int length;
  final ValueChanged<String>? onChanged;

  static final _count = NumberFormat('#,##0', 'en');

  @override
  State<AnswerArea> createState() => _AnswerAreaState();
}

class _AnswerAreaState extends State<AnswerArea> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(AnswerArea old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final rule = switch (widget.look) {
      AnswerLook.error => IqColors.err,
      AnswerLook.ready => IqColors.ok,
      AnswerLook.neutral =>
        widget.focusNode.hasFocus ? IqColors.brand : IqColors.line2,
    };
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.focusNode.requestFocus,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: IqSpace.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your answer',
              style: IqText.label.copyWith(color: IqColors.brand),
            ),
            const SizedBox(height: IqSpace.s2),
            // EditableText keeps 3 px at the line end for the caret; Figma
            // wraps the answer at the full width, so the field reaches past
            // the column by that much.
            LayoutBuilder(
              builder: (context, box) => OverflowBox(
                minWidth: box.maxWidth + _caretRoom,
                maxWidth: box.maxWidth + _caretRoom,
                alignment: AlignmentDirectional.centerStart,
                fit: OverflowBoxFit.deferToChild,
                child: _field(),
              ),
            ),
            const SizedBox(height: IqSpace.s2),
            AnimatedContainer(
              height: 2,
              duration: motion(context, IqDurations.tick),
              curve: IqCurves.easeOut,
              color: rule,
            ),
            const SizedBox(height: IqSpace.s2),
            Text(
              '${widget.length}/'
              '${AnswerArea._count.format(SubmitLimits.answerMax)} characters',
              style: IqText.small.copyWith(color: IqColors.fg2),
            ),
          ],
        ),
      ),
    );
  }

  static const double _caretRoom = 3;

  Widget _field() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 120),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        onChanged: widget.onChanged,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: [
          LengthLimitingTextInputFormatter(SubmitLimits.answerMax),
        ],
        style: IqText.body.copyWith(color: IqColors.fg),
        cursorColor: IqColors.brand,
        cursorWidth: 2,
        decoration: const InputDecoration.collapsed(hintText: null),
      ),
    );
  }
}

/// The steps under the pinned chrome: the new one slides in 24 from the
/// side it comes from and fades in while the old one slides 24 the other
/// way and fades, 300 ms forward and 240 back, both on one clock, as a push
/// would (MOTION-SPEC §3.1, §4.1: the chrome holds still). Reduced motion:
/// a 150 crossfade. Each step keeps its state while it leaves.
class StepSwitcher extends StatefulWidget {
  const StepSwitcher({super.key, required this.back, required this.child});

  /// The change went back a step.
  final bool back;
  final Widget child;

  @override
  State<StepSwitcher> createState() => _StepSwitcherState();
}

class _StepSwitcherState extends State<StepSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    value: 1,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onStatus);
  Widget? _leaving;
  bool _back = false;
  bool _reduced = false;

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted && _leaving != null && mounted) {
      setState(() => _leaving = null);
    }
  }

  @override
  void didUpdateWidget(StepSwitcher old) {
    super.didUpdateWidget(old);
    if (old.child.key == widget.child.key) return;
    _reduced = MediaQuery.disableAnimationsOf(context);
    _back = widget.back;
    _leaving = old.child;
    _clock.duration = _reduced
        ? IqDurations.crossfade
        : _back
        ? IqDurations.screenBack
        : IqDurations.screen;
    _clock.forward(from: 0);
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Widget _move(Widget child, {required bool incoming}) {
    return AnimatedBuilder(
      key: child.key,
      animation: _clock,
      child: child,
      builder: (context, child) {
        final t = _leaving == null ? 1.0 : _clock.value;
        if (_reduced) {
          return IgnorePointer(
            ignoring: !incoming,
            child: Opacity(opacity: incoming ? t : 1 - t, child: child),
          );
        }
        final double dx;
        final double opacity;
        if (incoming) {
          final from = _back ? -IqTravel.screen : IqTravel.screen;
          dx = from * (1 - IqCurves.easeOut.transform(t));
          opacity = const Interval(
            0,
            0.6,
            curve: IqCurves.easeOut,
          ).transform(t);
        } else {
          final to = _back ? IqTravel.screen : -IqTravel.screen;
          dx = to * IqCurves.easeIn.transform(t);
          opacity =
              1 - const Interval(0, 0.5, curve: IqCurves.easeIn).transform(t);
        }
        return IgnorePointer(
          ignoring: !incoming,
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(offset: Offset(dx, 0), child: child),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaving = _leaving;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        if (leaving != null) _move(leaving, incoming: false),
        _move(widget.child, incoming: true),
      ],
    );
  }
}

/// The Submit action bar (12 above and below a 52 pt button).
class SubmitActionBar extends StatelessWidget {
  const SubmitActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: IqColors.bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s4,
          vertical: IqSpace.s3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(height: IqSpace.s2),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
