import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

enum IqBoxFieldTone { ink, paper }

enum IqBoxFieldState { empty, active }

/// Exp/BoxField: the outlined entry box on the landing (email). Wraps a real
/// [TextField], text centred; [value] is the placeholder. [state] forces a
/// look; left null the box turns Active while it has focus.
///
/// Figma over brief: the set also has an Ink tone (white box, brand-fg2 text) and it is the default.
/// Figma over brief: typed text keeps the placeholder colour, centred, and the outline is 2 px on Active (1.5 at rest).
class IqBoxField extends StatefulWidget {
  const IqBoxField({
    super.key,
    this.value = 'Enter your email',
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
  });

  final String value;
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
    final active =
        (widget.state ??
            (_focus.hasFocus
                ? IqBoxFieldState.active
                : IqBoxFieldState.empty)) ==
        IqBoxFieldState.active;
    final ink = widget.tone == IqBoxFieldTone.ink;
    final textColor = ink ? IqColors.brandFg2 : IqColors.fg3;
    final style = IqText.body.copyWith(color: textColor);
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focus.requestFocus(),
        child: Container(
          width: widget.width,
          height: IqBoxField.height,
          padding: const EdgeInsets.symmetric(horizontal: IqSpace.s5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ink ? IqColors.card : null,
            borderRadius: BorderRadius.circular(IqBoxField.radius),
            border: Border.all(
              color: active
                  ? IqColors.accent
                  : ink
                  ? IqColors.brandLine
                  : IqColors.line2,
              width: active ? 2 : 1.5,
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
      ),
    );
  }
}
