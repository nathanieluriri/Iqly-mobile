import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../theme/theme.dart';
import 'icon.dart';
import 'pressable.dart';

enum IqDockActive {
  discover('Discover', IqIcons.discover),
  submissions('Submissions', IqIcons.submissions),
  wallet('Wallet', IqIcons.wallet),
  more('More', IqIcons.more);

  const IqDockActive(this.label, this.icon);

  final String label;
  final IqIcons icon;
}

/// Exp/Dock, the bottom navigation (designer doc rev 57, final): a full
/// width bar on paper with a 1 px hairline on top, no radius, shadow or
/// inset, 8 padding all round, sitting on the home indicator. Four equal
/// tabs, each a 22 px filled glyph over a label in a 10 by 8 cell, radius
/// 14. The active tab is a tint pill with an orange glyph and an ink label;
/// the others have no pill and both in fg3.
///
/// A switch is instant and gives the select haptic. The active tab is inert:
/// tapping it does nothing.
///
/// Doc over Figma: the component still draws the glyph at 24; the doc sets
/// 22.
class IqDock extends StatelessWidget {
  const IqDock({
    super.key,
    this.active = IqDockActive.discover,
    this.onChanged,
  });

  final IqDockActive active;
  final ValueChanged<IqDockActive>? onChanged;

  static const double glyph = 22;
  static const double hairline = 1;

  /// Hairline, padding, the tab cell (8 + glyph + 2 + label + 8), padding.
  static final double height =
      hairline +
      IqSpace.s2 * 4 +
      glyph +
      2 +
      IqText.label.fontSize! * IqText.label.height!;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(IqSpace.s2),
      decoration: const BoxDecoration(
        color: IqColors.bg,
        border: Border(
          top: BorderSide(color: IqColors.line, width: hairline),
        ),
      ),
      child: Row(
        children: [
          for (final item in IqDockActive.values)
            Expanded(
              child: _Tab(
                item: item,
                lit: item == active,
                onTap: onChanged == null || item == active
                    ? null
                    : () => onChanged!(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.lit, this.onTap});

  final IqDockActive item;
  final bool lit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: IqSpace.s2),
      decoration: BoxDecoration(
        color: lit ? IqColors.tint : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IqIcon(
            item.icon,
            size: IqDock.glyph,
            color: lit ? IqColors.accent : IqColors.fg3,
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: IqText.label.copyWith(
              color: lit ? IqColors.fg : IqColors.fg3,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      selected: lit,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: lit
          ? cell
          : IqPressable(
              onTap: onTap,
              haptic: IqHaptics.select,
              builder: (context, pressed) => cell,
            ),
    );
  }
}
