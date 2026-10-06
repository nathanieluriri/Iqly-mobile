import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'icon.dart';

enum IqMetaKind { reward, time, deadline, urgent, polls, done, plain, failed }

/// Exp/Meta: one fact per chip (the prize, the time it takes, the
/// deadline), at most three on a card. Urgent sits on the accent-soft pill;
/// the others are bare.
class IqMeta extends StatelessWidget {
  const IqMeta({
    super.key,
    this.kind = IqMetaKind.reward,
    this.label = '₦250,000 prize',
  });

  final IqMetaKind kind;
  final String label;

  static const double iconSize = 14;

  IqIcons? get _icon => switch (kind) {
    IqMetaKind.reward => IqIcons.trophy,
    IqMetaKind.time => IqIcons.clock,
    IqMetaKind.deadline || IqMetaKind.urgent => IqIcons.timer,
    IqMetaKind.polls => IqIcons.polls,
    IqMetaKind.done => IqIcons.check,
    IqMetaKind.failed => IqIcons.error,
    IqMetaKind.plain => null,
  };

  Color get _ink => switch (kind) {
    IqMetaKind.deadline || IqMetaKind.urgent => IqColors.brand,
    IqMetaKind.failed => IqColors.errStrong,
    _ => IqColors.fg2,
  };

  Color get _text => switch (kind) {
    IqMetaKind.reward || IqMetaKind.urgent => IqColors.fg,
    IqMetaKind.failed => IqColors.errStrong,
    _ => IqColors.fg2,
  };

  @override
  Widget build(BuildContext context) {
    final urgent = kind == IqMetaKind.urgent;
    final icon = _icon;
    return Container(
      padding: urgent
          ? const EdgeInsets.fromLTRB(IqSpace.s2, IqSpace.s1, 10, IqSpace.s1)
          : const EdgeInsets.symmetric(vertical: IqSpace.s0p5),
      decoration: urgent
          ? BoxDecoration(
              color: IqColors.accentSoft,
              borderRadius: BorderRadius.circular(IqRadius.full),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IqIcon(icon, size: iconSize, color: _ink),
            const SizedBox(width: IqSpace.s1),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: IqText.smallStrong.copyWith(color: _text),
            ),
          ),
        ],
      ),
    );
  }
}
