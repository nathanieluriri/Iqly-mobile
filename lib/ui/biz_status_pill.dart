import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

enum IqBizStatusPillStatus {
  underReview('Under review'),
  winner('Winner'),
  notSelected('Not selected'),
  draft('Draft');

  const IqBizStatusPillStatus(this.label);

  final String label;
}

/// Exp/Biz/StatusPill (1736:101083): a status in a table row, the product's
/// words. Under review is warn, Winner ok and Not selected brand on glass,
/// radius 8; Draft is the plain round pill.
class IqBizStatusPill extends StatelessWidget {
  const IqBizStatusPill({
    super.key,
    this.status = IqBizStatusPillStatus.underReview,
    this.label,
  });

  final IqBizStatusPillStatus status;

  /// In place of the status's own word.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (fill, stroke, ink) = switch (status) {
      IqBizStatusPillStatus.underReview => (
        IqColors.warnSoft,
        IqColors.warnDot,
        IqColors.warn,
      ),
      IqBizStatusPillStatus.winner => (
        IqColors.okSoft,
        IqColors.okDot,
        IqColors.ok,
      ),
      IqBizStatusPillStatus.notSelected => (
        IqColors.cardGlass,
        IqColors.brandLine,
        IqColors.brandFg2,
      ),
      IqBizStatusPillStatus.draft => (
        IqColors.card,
        IqColors.line,
        IqColors.fg2,
      ),
    };
    final draft = status == IqBizStatusPillStatus.draft;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: draft ? IqSpace.s2p5 : IqSpace.s2,
        vertical: IqSpace.s0p5,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(
          draft ? IqRadius.full : IqRadius.md,
        ),
        border: Border.all(color: stroke),
      ),
      child: Text(
        label ?? status.label,
        style: IqWebText.labelBadge.copyWith(color: ink),
      ),
    );
  }
}
