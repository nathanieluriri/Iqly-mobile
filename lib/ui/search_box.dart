import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqSearchBoxState { empty, typing }

/// Exp/SearchBox: the pill search box for lists (Help, states,
/// universities). Empty shows the placeholder; Typing shows the value, an
/// ink outline and a clear button. Give it a [controller] to type into it;
/// [state] then follows the text unless set.
class IqSearchBox extends StatefulWidget {
  const IqSearchBox({
    super.key,
    this.state,
    this.placeholder = 'Search help',
    this.value = 'withdraw',
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final IqSearchBoxState? state;
  final String placeholder;
  final String value;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  static const double height = 48;

  @override
  State<IqSearchBox> createState() => _IqSearchBoxState();
}

class _IqSearchBoxState extends State<IqSearchBox> {
  late final TextEditingController _own = TextEditingController(
    text: widget.state == IqSearchBoxState.typing ? widget.value : '',
  );

  TextEditingController get _controller => widget.controller ?? _own;

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final typing =
            (widget.state ??
                (_controller.text.isEmpty
                    ? IqSearchBoxState.empty
                    : IqSearchBoxState.typing)) ==
            IqSearchBoxState.typing;
        return Container(
          height: IqSearchBox.height,
          padding: const EdgeInsets.only(left: IqSpace.s4, right: 14),
          decoration: BoxDecoration(
            color: IqColors.card,
            borderRadius: BorderRadius.circular(IqSearchBox.height / 2),
            border: Border.all(
              color: typing ? IqColors.fg : IqColors.line,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              IqIcon(
                IqIcons.search,
                size: 20,
                color: typing ? IqColors.fg : IqColors.fg3,
              ),
              const SizedBox(width: IqSpace.s2p5),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: widget.focusNode,
                  autofocus: widget.autofocus,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  textInputAction: TextInputAction.search,
                  cursorColor: IqColors.brand,
                  style: IqText.body.copyWith(color: IqColors.fg),
                  decoration: InputDecoration.collapsed(
                    hintText: widget.placeholder,
                    hintStyle: IqText.body.copyWith(color: IqColors.fg3),
                  ),
                ),
              ),
              if (typing) ...[
                const SizedBox(width: IqSpace.s2p5),
                IqPressable(
                  semanticLabel: 'Clear search',
                  hint: 'Clear search',
                  onTap: () {
                    _controller.clear();
                    widget.onChanged?.call('');
                  },
                  builder: (context, pressed) => const IqIcon(
                    IqIcons.close,
                    size: 18,
                    color: IqColors.fg3,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
