import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../core/motion.dart';
import '../../data/submit_data.dart';
import '../../theme/theme.dart';
import '../../ui/highlight.dart';
import '../../ui/icon.dart';
import '../../ui/illustration.dart';
import '../../ui/pressable.dart';

/// How the answer area judges its text, which the pinned thread mirrors.
enum AnswerLook { neutral, error, ready }

/// The 34:24 text area: a plain frame, not an Exp/Field (the long answer
/// grows past one line): YOUR ANSWER in brand mono, the answer in Mob/Body,
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
              'Your answer'.toUpperCase(),
              style: IqText.mono.copyWith(color: IqColors.brand),
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

/// An attached file under the Attachments row, with its size the way
/// iqly.net writes it ("(240 KB)") and a 44 pt remove button.
class AttachedFileRow extends StatelessWidget {
  const AttachedFileRow({
    super.key,
    required this.file,
    required this.onRemove,
  });

  final AttachmentFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: IqSpace.s4),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '${file.name} ',
              style: IqText.body.copyWith(color: IqColors.fg),
              children: [
                TextSpan(
                  text: '(${(file.bytes / 1024).round()} KB)',
                  style: IqText.small.copyWith(color: IqColors.fg3),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IqPressable(
          onTap: onRemove,
          semanticLabel: 'Remove ${file.name}',
          builder: (context, pressed) => SizedBox.square(
            dimension: 44,
            child: Center(
              child: PressDim(
                pressed: pressed,
                child: const IqIcon(
                  IqIcons.close,
                  size: 18,
                  color: IqColors.fg3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The Bulb arriving on the sent moment (MOTION-SPEC §5.29, §7.4): the ink
/// rises 16 as it fades in over 320 ms ease-out, then from +160 the orange
/// sweep wipes in left to right across its own bounds (240), the idea lit.
/// Reduced motion: the ink fades in over 150 and the sweep is there.
class BulbArrival extends StatefulWidget {
  const BulbArrival({super.key});

  @override
  State<BulbArrival> createState() => _BulbArrivalState();
}

class _BulbArrivalState extends State<BulbArrival>
    with SingleTickerProviderStateMixin {
  static final _length = IqDurations.stagger * 4 + IqDurations.mark;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  late Animation<double> _ink = _clock;
  late Animation<double> _sweep = _clock;
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
      _ink = _clock.drive(CurveTween(curve: IqCurves.easeOut));
      _sweep = kAlwaysCompleteAnimation;
    } else {
      final total = _length.inMicroseconds;
      Interval span(Duration at, Duration length) => Interval(
        at.inMicroseconds / total,
        (at + length).inMicroseconds / total,
        curve: IqCurves.easeOut,
      );
      _clock.duration = _length;
      _ink = _clock.drive(
        CurveTween(curve: span(Duration.zero, IqDurations.morph)),
      );
      _sweep = _clock.drive(
        CurveTween(curve: span(IqDurations.stagger * 4, IqDurations.mark)),
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
    return SizedBox(
      width: IqIllustration.designWidth,
      height: IqIllustration.designHeight,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) => Stack(
          children: [
            Opacity(
              opacity: _ink.value,
              child: Transform.translate(
                offset: Offset(
                  0,
                  _reduced ? 0 : IqTravel.riseHero * (1 - _ink.value),
                ),
                child: const IllustrationLayer(IqIllustrations.bulb, 'ink'),
              ),
            ),
            ClipRect(
              clipper: _SweepClip(_sweep.value, from: 126 / 200, to: 165 / 200),
              child: const IllustrationLayer(IqIllustrations.bulb, 'accent'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One named layer of an Exp/Illustration ("ink" or "accent"); the other is
/// drawn clear, so no new asset is needed.
class IllustrationLayer extends StatelessWidget {
  const IllustrationLayer(this.kind, this.layer, {super.key});

  final IqIllustrations kind;
  final String layer;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      kind.asset,
      width: IqIllustration.designWidth,
      height: IqIllustration.designHeight,
      excludeFromSemantics: true,
      colorMapper: _Layer(layer),
    );
  }
}

class _Layer extends ColorMapper {
  const _Layer(this.keep);

  final String keep;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => (id == 'accent') == (keep == 'accent') ? color : Colors.transparent;

  @override
  bool operator ==(Object other) => other is _Layer && other.keep == keep;

  @override
  int get hashCode => keep.hashCode;
}

/// Reveals [reveal] of the stretch between [from] and [to] (shares of the
/// width), left to right; everything left of [from] shows.
class _SweepClip extends CustomClipper<Rect> {
  const _SweepClip(this.reveal, {required this.from, required this.to});

  final double reveal;
  final double from;
  final double to;

  @override
  Rect getClip(Size size) {
    if (reveal >= 1) return Offset.zero & size;
    final right = size.width * (from + (to - from) * reveal.clamp(0.0, 1.0));
    return Rect.fromLTRB(0, 0, right, size.height);
  }

  @override
  bool shouldReclip(_SweepClip old) => old.reveal != reveal;
}

/// An Exp/Highlight whose marker wipes in from [at] (MOTION-SPEC §7.4: from
/// +240): until then its words stand plain in the same place, then the
/// Highlight mounts and wipes in its own 240. Reduced motion: the Highlight
/// from the start.
class DelayedHighlight extends StatefulWidget {
  const DelayedHighlight({
    super.key,
    required this.text,
    required this.tone,
    required this.at,
  });

  final String text;
  final IqHighlightTone tone;
  final Duration at;

  @override
  State<DelayedHighlight> createState() => _DelayedHighlightState();
}

class _DelayedHighlightState extends State<DelayedHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wait = AnimationController(
    vsync: this,
    duration: widget.at,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onWait);
  bool _shown = false;
  bool _started = false;

  void _onWait(AnimationStatus status) {
    if (status.isCompleted && mounted) setState(() => _shown = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context) || widget.at == Duration.zero) {
      _shown = true;
    } else {
      _wait.forward();
    }
  }

  @override
  void dispose() {
    _wait.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shown) return IqHighlight(text: widget.text, tone: widget.tone);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s1, vertical: 1),
      child: Text(
        widget.text,
        maxLines: 1,
        softWrap: false,
        style: IqText.bodyStrong.copyWith(color: IqColors.brand),
      ),
    );
  }
}
