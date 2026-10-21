import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';

/// Exp/Biz/SearchField (1734:18225): the 44 tall table search, radius 8,
/// the search glyph before the query.
class IqBizSearchField extends StatelessWidget {
  const IqBizSearchField({
    super.key,
    this.placeholder = 'Search submissions',
    this.controller,
    this.onChanged,
  });

  final String placeholder;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: IqSpace.s2p5, right: IqSpace.s3),
      decoration: BoxDecoration(
        color: IqColors.card,
        borderRadius: BorderRadius.circular(IqRadius.md),
        border: Border.all(color: IqColors.line),
      ),
      child: Row(
        children: [
          const IqIcon(IqIcons.search, size: 16, color: IqColors.fg),
          const SizedBox(width: IqSpace.s2),
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                cursorColor: IqColors.primary,
                style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
                decoration: InputDecoration.collapsed(
                  hintText: placeholder,
                  hintStyle: IqWebText.bodySmall.copyWith(color: IqColors.fg3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
