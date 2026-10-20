import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/motion.dart';
import '../../theme/theme.dart';

final _count = NumberFormat('#,##0', 'en');

/// "16/5,000": what is written over the most the field takes.
String fieldCount(int length, int max) =>
    '${_count.format(length)}/${_count.format(max)}';

/// The submit page's fields, the local Exp/Field of the app file
/// (1710:34492, "local, sync to DS"), kept with the page until the design
/// system takes it: the label with the requirement beside it, the text,
/// an underline, then the count. Active is the label in brand over a 2 pt
/// accent line; Error is the label, line and [help] in err. Many lines
/// opens with [inputHeight] of room and grows with the text.
///
/// Figma over Exp/Field (IqField): the requirement sits in the head and the
/// count in the foot, and the screens hide the help line except on Error.
class SubmitField extends StatefulWidget {
  const SubmitField({
    super.key,
    required this.label,
    required this.requirement,
    required this.placeholder,
    required this.counter,
    required this.controller,
    required this.focusNode,
    this.error = false,
    this.help,
    this.many = false,
    this.inputHeight = defaultInputHeight,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final String requirement;
  final String placeholder;
  final String counter;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool error;

  /// Shown under the line in Error.
  final String? help;
  final bool many;
  final double inputHeight;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  static const double defaultInputHeight = 140;
  static const double _gap = 6;
  static const double _line = 2;

  /// Everything but the text at the reader's text size: head, foot, the
  /// gaps and the thicker line.
  static double chromeOf(BuildContext context) {
    final painter = TextPainter(
      text: const TextSpan(text: 'Title', style: IqText.small),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final line = painter.height;
    painter.dispose();
    return line * 2 + _gap * 3 + _line;
  }

  @override
  State<SubmitField> createState() => _SubmitFieldState();
}

class _SubmitFieldState extends State<SubmitField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(SubmitField old) {
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
    final error = widget.error;
    final active = widget.focusNode.hasFocus;
    final ink = error
        ? IqColors.err
        : active
        ? IqColors.brand
        : IqColors.fg2;
    final (rule, thick) = error
        ? (IqColors.err, true)
        : active
        ? (IqColors.accent, true)
        : (IqColors.line, false);
    final help = widget.help;
    final duration = motion(context, IqDurations.tick);
    final field = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      maxLines: widget.many ? null : 1,
      keyboardType: widget.many ? TextInputType.multiline : null,
      textInputAction: widget.textInputAction,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: widget.inputFormatters,
      style: IqText.body.copyWith(color: IqColors.fg),
      cursorColor: IqColors.brand,
      cursorWidth: 2,
      decoration: InputDecoration.collapsed(
        hintText: widget.placeholder,
        hintStyle: IqText.body.copyWith(color: IqColors.fg3),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.focusNode.requestFocus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: IqCurves.easeOut,
                    style: IqText.label.copyWith(color: ink),
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: IqSpace.s2),
                Text(
                  widget.requirement,
                  style: IqText.small.copyWith(color: IqColors.fg2),
                ),
              ],
            ),
          ),
          const SizedBox(height: SubmitField._gap),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.many ? math.max(0, widget.inputHeight) : 0,
            ),
            child: MergeSemantics(
              child: Semantics(label: widget.label, child: field),
            ),
          ),
          const SizedBox(height: SubmitField._gap),
          SizedBox(
            height: SubmitField._line,
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedContainer(
                duration: duration,
                curve: IqCurves.easeOut,
                height: thick ? SubmitField._line : 1,
                color: rule,
              ),
            ),
          ),
          const SizedBox(height: SubmitField._gap),
          Row(
            children: [
              Expanded(
                child: error && help != null
                    ? Semantics(
                        liveRegion: true,
                        child: Text(
                          help,
                          style: IqText.small.copyWith(color: IqColors.err),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: IqSpace.s2),
              Text(
                widget.counter,
                style: IqText.small.copyWith(color: IqColors.fg2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
