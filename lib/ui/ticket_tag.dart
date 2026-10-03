import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'icon.dart';

enum IqTicketTagKind { open, replied, resolved }

/// Exp/TicketTag: the help-thread state as a pill with a 14 px brush icon.
/// [label] defaults to the Figma words per kind. A new kind crossfades,
/// 150 ms (a cut under reduced motion).
///
/// Figma over its title: a plain pill, no tail.
/// Figma over the icon rule: icons sit at 14 px, below the 16 px minimum.
/// Figma over brief: Replied keeps its chat icon in brand ink.
class IqTicketTag extends StatelessWidget {
  const IqTicketTag({super.key, this.kind = IqTicketTagKind.open, this.label});

  final IqTicketTagKind kind;
  final String? label;

  static const Duration fade = Duration(milliseconds: 150);

  static String defaultLabel(IqTicketTagKind kind) => switch (kind) {
    IqTicketTagKind.open => 'Open',
    IqTicketTagKind.replied => 'Support replied',
    IqTicketTagKind.resolved => 'Resolved',
  };

  @override
  Widget build(BuildContext context) {
    final (fill, ink, icon) = switch (kind) {
      IqTicketTagKind.open => (IqColors.panel, IqColors.fg2, IqIcons.info),
      IqTicketTagKind.replied => (
        IqColors.accentSoft,
        IqColors.brand,
        IqIcons.chat,
      ),
      IqTicketTagKind.resolved => (IqColors.okSoft, IqColors.ok, IqIcons.check),
    };
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : fade,
      child: Container(
        key: ValueKey(kind),
        padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(IqRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IqIcon(icon, size: 14, color: ink),
            const SizedBox(width: IqSpace.s1p5),
            Flexible(
              child: Text(
                label ?? defaultLabel(kind),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: IqText.smallStrong.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
