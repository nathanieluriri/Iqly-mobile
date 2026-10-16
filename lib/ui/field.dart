import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';
import 'vector.dart';

enum IqFieldKind { text, picker }

enum IqFieldState { empty, active, valid, error }

/// Figma Size=Default is [standard].
enum IqFieldSize { standard, large }

/// Exp/Field: the one text entry component, a Mob/Label label over the
/// value, an underline and a help line. Text wraps a real [TextField]; [value]
/// is the placeholder Figma shows in the Empty state. [state] forces a look;
/// left null (or Empty) the field turns Active while it has focus. Picker is
/// a tap target that opens the caller's sheet through [onTap].
///
/// Figma over brief: Valid draws only the hairline base, no ink brush.
/// Figma over brief: the mock caret is on Size=Large Active only (a focused field still shows the live cursor).
/// Figma over brief: Picker Valid hides the help line.
/// Figma over brief: the Active label is Color/primary, the Error label Color/err-strong.
/// Figma over brief: since the 5 Oct update the label is Mob/Label in
/// sentence case (not mono caps) and Active draws a straight 2 pt accent
/// line, not the brush; Error keeps the err brush.
/// Screens hide the status icon and the note on some Valid instances (B0
/// Your name, Sign in): [showStatus] and [showNote] carry those overrides.
///
/// A text field is one semantics node the height of the field, carrying
/// [label], so a screen reader reads "Phone number, text field" and the
/// whole 62 pt target counts.
///
/// Motion (MOTION-SPEC 5.8): the label colour and the base line cross over
/// 160 ms ease-out; turning Active or Error wipes the accent or err brush in
/// left to right (240), and a brush that goes fades out (150, reading
/// ease-in); the success and error icons pop from .6 (220) and fade when
/// they go (150); the help line or note opens its own slot as it rises in
/// (160), so the rows below move with it, and folds away as it fades
/// (150). A new picker value crossfades in (200). Pressing a picker dims
/// its label and value to .6 (100 in, 160 out). The screen adds the shake
/// (lib/core/motion). Reduced motion: colours and icons change at once, the
/// brush shows whole, the help line crossfades over 150 in place.
///
/// A Text field takes several lines through [maxLines] (the B10 help
/// message; Figma draws that one as a plain frame).
class IqField extends StatefulWidget {
  const IqField({
    super.key,
    this.kind = IqFieldKind.text,
    this.state,
    this.size = IqFieldSize.standard,
    this.label = 'Account number',
    this.value = '0123456789',
    this.help = 'Could not verify account. Check the number and bank.',
    this.note = 'Verified: ADAEZE OKAFOR',
    this.pickerLabel = 'Bank',
    this.pickerValue = 'Access Bank',
    this.pickerPlaceholder = 'Select bank',
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofocus = false,
    this.obscureText = false,
    this.autofillHints,
    this.showStatus = true,
    this.showNote = true,
    this.maxLines = 1,
    this.minLines,
  });

  final IqFieldKind kind;
  final IqFieldState? state;
  final IqFieldSize size;
  final String label;
  final String value;
  final String help;
  final String note;
  final String pickerLabel;
  final String pickerValue;
  final String pickerPlaceholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final bool showStatus;
  final bool showNote;
  final int? maxLines;
  final int? minLines;

  @override
  State<IqField> createState() => _IqFieldState();
}

class _IqFieldState extends State<IqField> {
  FocusNode? _ownFocus;

  TextEditingController? _ownController;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(IqField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  bool get _isText => widget.kind == IqFieldKind.text;
  bool get _large => widget.size == IqFieldSize.large;

  IqFieldState get _resolved {
    final forced = widget.state;
    if (_isText && (forced == null || forced == IqFieldState.empty)) {
      return _focus.hasFocus ? IqFieldState.active : IqFieldState.empty;
    }
    return forced ?? IqFieldState.empty;
  }

  // A TextField cannot end a line in an ellipsis, so at rest a single line
  // value too wide for the field is painted over the field's transparent
  // text, as Figma truncates it. The mirror is paint only: finders and
  // semantics still see the one field.
  Widget _textValue(String text, TextStyle style) {
    final canTruncate =
        widget.maxLines == 1 &&
        !widget.obscureText &&
        !_focus.hasFocus &&
        text.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!canTruncate) return _textStack(text, style, false);
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return _textStack(text, style, overflows);
      },
    );
  }

  Widget _textStack(String text, TextStyle style, bool atRest) {
    return Stack(
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          autofocus: widget.autofocus,
          obscureText: widget.obscureText,
          autocorrect: !widget.obscureText,
          enableSuggestions: !widget.obscureText,
          autofillHints: widget.autofillHints,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          style: style.copyWith(
            color: atRest ? IqColors.fg.withValues(alpha: 0) : IqColors.fg,
          ),
          cursorColor: IqColors.brand,
          cursorWidth: 2,
          cursorHeight: _large ? 26 : null,
          decoration: InputDecoration.collapsed(
            hintText: widget.value,
            hintStyle: style.copyWith(color: IqColors.fg3),
          ),
        ),
        if (atRest)
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RichText(
                  text: TextSpan(
                    text: text,
                    style: style.copyWith(color: IqColors.fg),
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _resolved;
    final valueStyle = _large ? IqText.title : IqText.body;
    final colour = motion(context, IqDurations.tick);
    final labelColor = switch (state) {
      IqFieldState.active => IqColors.primary,
      IqFieldState.error => IqColors.errStrong,
      _ => IqColors.fg3,
    };
    final showHelp =
        (state == IqFieldState.error && widget.help.isNotEmpty) ||
        (state == IqFieldState.valid && _isText && widget.showNote);
    final mockCaret =
        _large &&
        state == IqFieldState.active &&
        (!_isText || !_focus.hasFocus);

    final valueLine = _isText
        ? ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => _textValue(value.text, valueStyle),
          )
        : _PickerValue(
            text: state == IqFieldState.empty
                ? widget.pickerPlaceholder
                : widget.pickerValue,
            style: valueStyle.copyWith(
              color: state == IqFieldState.empty ? IqColors.fg3 : IqColors.fg,
            ),
          );

    final label = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: labelColor),
      duration: colour,
      curve: IqCurves.easeOut,
      builder: (context, color, _) => Text(
        _isText ? widget.label : widget.pickerLabel,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: IqText.label.copyWith(color: color ?? labelColor),
      ),
    );

    Widget row(bool pressed) => Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: IqSpace.s0p5,
            vertical: _large ? IqSpace.s2 : IqSpace.s1p5,
          ),
          child: Row(
            children: [
              Expanded(
                child: PressDim(
                  pressed: pressed,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isText ? ExcludeSemantics(child: label) : label,
                      SizedBox(height: _large ? IqSpace.s1 : IqSpace.s0p5),
                      valueLine,
                    ],
                  ),
                ),
              ),
              _Status(
                icon: !widget.showStatus
                    ? null
                    : switch (state) {
                        IqFieldState.valid => const IqIcon(
                          IqIcons.success,
                          key: ValueKey(IqFieldState.valid),
                          size: 22,
                          color: IqColors.ok,
                        ),
                        IqFieldState.error => const IqIcon(
                          IqIcons.error,
                          key: ValueKey(IqFieldState.error),
                          size: 22,
                          color: IqColors.err,
                        ),
                        _ => null,
                      },
              ),
              if (!_isText) ...[
                const SizedBox(width: IqSpace.s3),
                const IqIcon(IqIcons.down, size: 20, color: IqColors.fg2),
              ],
            ],
          ),
        ),
        if (mockCaret)
          const Positioned(
            left: IqSpace.s0p5,
            top: 24,
            width: 2,
            height: 26,
            child: ColoredBox(color: IqColors.brand),
          ),
      ],
    );

    final base = SizedBox(
      height: 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -0.83,
            right: -0.44,
            top: 0,
            height: 6.05,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(
                end: state == IqFieldState.empty
                    ? IqColors.line2
                    : IqColors.line,
              ),
              duration: colour,
              curve: IqCurves.easeOut,
              builder: (context, color, _) => IqVector(
                'assets/vectors/field-base.svg',
                color: color ?? IqColors.line,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 1.14,
            height: 4,
            child: _Brush(state: state),
          ),
        ],
      ),
    );

    Widget body(bool pressed) {
      final field = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          row(pressed),
          const SizedBox(height: IqSpace.s1p5),
          base,
        ],
      );
      return ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isText)
              MergeSemantics(
                child: Semantics(label: widget.label, child: field),
              )
            else
              field,
            RevealSlot(
              shown: showHelp,
              child: Padding(
                key: ValueKey((state == IqFieldState.error, widget.help)),
                padding: const EdgeInsets.only(top: IqSpace.s1p5),
                child: state == IqFieldState.valid
                    ? Text(
                        widget.note,
                        style: IqText.small.copyWith(color: IqColors.ok),
                      )
                    : Semantics(
                        liveRegion: true,
                        child: Text(
                          widget.help,
                          style: IqText.small.copyWith(
                            color: IqColors.errStrong,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isText) {
      return Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          excludeFromSemantics: true,
          onTap: () => _focus.requestFocus(),
          child: body(false),
        ),
      );
    }
    return IqPressable(
      onTap: widget.onTap,
      semanticLabel:
          '${widget.pickerLabel}, ${state == IqFieldState.empty ? widget.pickerPlaceholder : widget.pickerValue}',
      builder: (context, pressed) => body(pressed),
    );
  }
}

/// The status icon slot: an icon that comes pops in from .6 (220 ms) and
/// one that goes fades (150).
class _Status extends StatelessWidget {
  const _Status({required this.icon});

  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return AnimatedSwitcher(
      duration: motion(context, IqDurations.appear),
      reverseDuration: motion(context, IqDurations.crossfade),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) => Transform.scale(
            scale: animation.status == AnimationStatus.reverse
                ? 1
                : IqScale.pop + (1 - IqScale.pop) * animation.value,
            child: child,
          ),
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: icon == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Padding(
              key: icon.key,
              padding: const EdgeInsetsDirectional.only(start: IqSpace.s3),
              child: icon,
            ),
    );
  }
}

/// The accent or err brush under an Active or Error field: it wipes in
/// left to right and fades out when the state moves on.
class _Brush extends StatelessWidget {
  const _Brush({required this.state});

  final IqFieldState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      IqFieldState.active => IqColors.accent,
      IqFieldState.error => IqColors.err,
      _ => null,
    };
    return AnimatedSwitcher(
      duration: Duration.zero,
      reverseDuration: motion(context, IqDurations.crossfade),
      switchOutCurve: IqCurves.easeOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: color == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Wipe(
              key: ValueKey(state),
              child: state == IqFieldState.active
                  ? const _FocusLine()
                  : IqVector('assets/vectors/field-stroke.svg', color: color),
            ),
    );
  }
}

/// Figma's Active focus-line: a 2 pt accent rule 4 below the underline top,
/// which sits 2.86 into the brush box.
class _FocusLine extends StatelessWidget {
  const _FocusLine();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 2.86,
          height: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: IqColors.accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerValue extends StatelessWidget {
  const _PickerValue({required this.text, required this.style});

  final String text;
  final TextStyle style;

  static const duration = IqDurations.swap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motion(context, duration),
      switchInCurve: IqCurves.easeOut,
      switchOutCurve: IqCurves.easeOut,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: Text(
        text,
        key: ValueKey((text, style.color)),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
