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

/// Exp/Field: the one text entry component, a mono label over the value, a
/// brush underline and a help line. Text wraps a real [TextField]; [value]
/// is the placeholder Figma shows in the Empty state. [state] forces a look;
/// left null (or Empty) the field turns Active while it has focus. Picker is
/// a tap target that opens the caller's sheet through [onTap].
///
/// Figma over brief: Valid draws only the hairline base, no ink brush.
/// Figma over brief: the mock caret is on Size=Large Active only (a focused field still shows the live cursor).
/// Figma over brief: Picker Valid hides the help line.
/// Figma over brief: the Active label is Color/primary, the Error label Color/err-strong.
/// Screens hide the status icon and the note on some Valid instances (B0
/// Your name, Sign in): [showStatus] and [showNote] carry those overrides.
/// A new picker value crossfades in (200 ms ease-out, none under reduced
/// motion). Turning to Error wipes the err stroke in left to right (240 ms)
/// and the help line rises in (160 ms); the screen adds the shake
/// (lib/core/motion).
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

  @override
  State<IqField> createState() => _IqFieldState();
}

class _IqFieldState extends State<IqField> {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

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

  @override
  Widget build(BuildContext context) {
    final state = _resolved;
    final valueStyle = _large ? IqText.title : IqText.body;
    final labelColor = switch (state) {
      IqFieldState.active => IqColors.primary,
      IqFieldState.error => IqColors.errStrong,
      _ => IqColors.fg3,
    };
    final showHelp =
        state == IqFieldState.error ||
        (state == IqFieldState.valid && _isText && widget.showNote);
    final mockCaret =
        _large &&
        state == IqFieldState.active &&
        (!_isText || !_focus.hasFocus);

    final valueLine = _isText
        ? TextField(
            controller: widget.controller,
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
            maxLines: 1,
            style: valueStyle.copyWith(color: IqColors.fg),
            cursorColor: IqColors.brand,
            cursorWidth: 2,
            cursorHeight: _large ? 26 : null,
            decoration: InputDecoration.collapsed(
              hintText: widget.value,
              hintStyle: valueStyle.copyWith(color: IqColors.fg3),
            ),
          )
        : _PickerValue(
            text: state == IqFieldState.empty
                ? widget.pickerPlaceholder
                : widget.pickerValue,
            style: valueStyle.copyWith(
              color: state == IqFieldState.empty ? IqColors.fg3 : IqColors.fg,
            ),
          );

    final row = Stack(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (_isText ? widget.label : widget.pickerLabel)
                          .toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: IqText.mono.copyWith(color: labelColor),
                    ),
                    SizedBox(height: _large ? IqSpace.s1 : IqSpace.s0p5),
                    valueLine,
                  ],
                ),
              ),
              if (state == IqFieldState.valid && widget.showStatus) ...[
                const SizedBox(width: IqSpace.s3),
                const IqIcon(IqIcons.success, size: 22, color: IqColors.ok),
              ],
              if (state == IqFieldState.error && widget.showStatus) ...[
                const SizedBox(width: IqSpace.s3),
                const IqIcon(IqIcons.error, size: 22, color: IqColors.err),
              ],
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

    final body = ClipRect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          row,
          const SizedBox(height: IqSpace.s1p5),
          SizedBox(
            height: 6,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -0.83,
                  right: -0.44,
                  top: 0,
                  height: 6.05,
                  child: IqVector(
                    'assets/vectors/field-base.svg',
                    color: state == IqFieldState.empty
                        ? IqColors.line2
                        : IqColors.line,
                  ),
                ),
                if (state == IqFieldState.active)
                  const Positioned(
                    key: ValueKey('stroke-active'),
                    left: 0,
                    right: 0,
                    top: 1.14,
                    height: 4,
                    child: IqVector(
                      'assets/vectors/field-stroke.svg',
                      color: IqColors.accent,
                    ),
                  ),
                if (state == IqFieldState.error)
                  const Positioned(
                    key: ValueKey('stroke-error'),
                    left: 0,
                    right: 0,
                    top: 1.14,
                    height: 4,
                    child: Wipe(
                      child: IqVector(
                        'assets/vectors/field-stroke.svg',
                        color: IqColors.err,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (showHelp) ...[
            const SizedBox(height: IqSpace.s1p5),
            if (state == IqFieldState.valid)
              Text(
                widget.note,
                style: IqText.small.copyWith(color: IqColors.ok),
              )
            else
              Reveal(
                key: ValueKey(widget.help),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.help,
                    style: IqText.small.copyWith(color: IqColors.errStrong),
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    if (_isText) {
      return Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _focus.requestFocus(),
          child: body,
        ),
      );
    }
    return IqPressable(
      onTap: widget.onTap,
      semanticLabel:
          '${widget.pickerLabel}, ${state == IqFieldState.empty ? widget.pickerPlaceholder : widget.pickerValue}',
      builder: (context, pressed) => body,
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
