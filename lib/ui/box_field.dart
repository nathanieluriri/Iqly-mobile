import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/motion.dart';
import '../theme/theme.dart';

enum IqBoxFieldTone { ink, paper }

enum IqBoxFieldState { empty, active, error }

/// Exp/BoxField: the outlined entry box on the landing (email). Wraps a real
/// [TextField], text centred; [value] is the placeholder. [state] forces a
/// look; left null the box turns Active while it has focus.
///
/// Figma over brief: the set also has an Ink tone (white box, brand-fg2 text) and it is the default.
/// Figma over brief: typed text keeps the placeholder colour, centred, and the outline is 2 px on Active (1.5 at rest).
/// Not in Figma: the set has no Error variant. Error borrows the Field Error
/// language: a 2 px err outline in place of the accent, and [help] 6 px below
/// in Mob/Small err-strong (err-soft on the Ink tone's brand ground), centred
/// like the value, rising in as the Field help does.
///
/// Motion (MOTION-SPEC 5.9): the outline's colour and width cross over in
/// 160 ms ease-out on focus and on error; the help line opens its own slot
/// as it rises in (160) and folds away as it fades (150), so nothing below
/// jumps. The screen adds the shake. Reduced motion: the outline changes at
/// once and the help line crossfades in place over 150.
///
/// [scrollPadding] is the room kept clear around the caret when a scroll
/// view brings the box into view above the keyboard.
class IqBoxField extends StatefulWidget {
  const IqBoxField({
    super.key,
    this.value = 'Enter your email',
    this.help = '',
    this.tone = IqBoxFieldTone.ink,
    this.state,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType = TextInputType.emailAddress,
    this.textInputAction = TextInputAction.done,
    this.inputFormatters,
    this.autofocus = false,
    this.width = 358,
    this.scrollPadding = const EdgeInsets.all(20),
  });

  final String value;
  final String help;
  final IqBoxFieldTone tone;
  final IqBoxFieldState? state;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final double width;
  final EdgeInsets scrollPadding;

  static const double height = 56;
  static const double radius = 16;

  @override
  State<IqBoxField> createState() => _IqBoxFieldState();
}

class _IqBoxFieldState extends State<IqBoxField> {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(IqBoxField old) {
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

  @override
  Widget build(BuildContext context) {
    final state =
        widget.state ??
        (_focus.hasFocus ? IqBoxFieldState.active : IqBoxFieldState.empty);
    final ink = widget.tone == IqBoxFieldTone.ink;
    final textColor = ink ? IqColors.brandFg2 : IqColors.fg3;
    final style = IqText.body.copyWith(color: textColor);
    final box = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: AnimatedContainer(
        duration: motion(context, IqDurations.tick),
        curve: IqCurves.easeOut,
        width: widget.width,
        height: IqBoxField.height,
        padding: const EdgeInsets.symmetric(horizontal: IqSpace.s5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ink ? IqColors.card : null,
          borderRadius: BorderRadius.circular(IqBoxField.radius),
          border: Border.all(
            color: switch (state) {
              IqBoxFieldState.active => IqColors.accent,
              IqBoxFieldState.error => IqColors.err,
              IqBoxFieldState.empty =>
                ink ? IqColors.brandLine : IqColors.line2,
            },
            width: state == IqBoxFieldState.empty ? 1.5 : 2,
          ),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          autofocus: widget.autofocus,
          autocorrect: false,
          scrollPadding: widget.scrollPadding,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: style,
          cursorColor: IqColors.brand,
          cursorWidth: 2,
          decoration: InputDecoration.collapsed(
            hintText: widget.value,
            hintStyle: style,
          ),
        ),
      ),
    );
    // The box stays the first child either way, so the text field keeps its
    // element (and the keyboard) when the help line comes and goes.
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            box,
            RevealSlot(
              shown: state == IqBoxFieldState.error && widget.help.isNotEmpty,
              child: Padding(
                key: ValueKey(widget.help),
                padding: const EdgeInsets.only(top: IqSpace.s1p5),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.help,
                    textAlign: TextAlign.center,
                    style: IqText.small.copyWith(
                      color: ink ? IqColors.errSoft : IqColors.errStrong,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
