import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'biz_ledger_header.dart';
import 'cover_with_logo.dart';
import 'icon.dart';
import 'pressable.dart';

/// Exp/Web/ActivationRow (local, sync to DS; 1740:20362): one activation
/// in the table, 24 in. The cover with the logo beside the business, the
/// title and where your run stands, then Reward, Spots (landscape) and
/// Closes, and the chevron. Rows open on tap; there is no hover. [columns]
/// are the table's: the activation, then one per cell given.
class IqWebActivationRow extends StatelessWidget {
  const IqWebActivationRow({
    super.key,
    required this.columns,
    required this.business,
    required this.title,
    required this.status,
    required this.cover,
    required this.logo,
    required this.reward,
    required this.closes,
    this.spots,
    this.statusWarm = false,
    this.spotsLow = false,
    this.onTap,
  });

  final List<IqBizLedgerColumn> columns;
  final String business;
  final String title;
  final String status;
  final Widget cover;
  final Widget logo;
  final String reward;

  /// The deadline cell: a plain line or the Urgent pill.
  final Widget closes;
  final String? spots;

  /// A run waiting on a step reads in the warm accent.
  final bool statusWarm;
  final bool spotsLow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spots = this.spots;
    final cells = <Widget>[
      Row(
        children: [
          CoverWithLogo(
            size: const Size.square(56),
            radius: IqRadius.xl,
            cover: cover,
            logo: logo,
            logoOffset: const Offset(38, 38),
            logoSize: 26,
            logoInset: 2,
          ),
          const SizedBox(width: IqSpace.s6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business,
                  style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqWebText.headingCardSection.copyWith(
                    color: IqColors.fg,
                  ),
                ),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqWebText.metaCaption.copyWith(
                    color: statusWarm ? IqColors.accentStrong : IqColors.fg2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      Text(reward, style: IqWebText.bodySmall.copyWith(color: IqColors.fg)),
      if (spots != null)
        Text(
          spots,
          style: IqWebText.bodySmall.copyWith(
            color: spotsLow ? IqColors.err : IqColors.fg2,
          ),
        ),
      closes,
    ];
    return IqPressable(
      onTap: onTap,
      tactile: false,
      semanticLabel: '$business, $title',
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s6,
          vertical: IqSpace.s3,
        ),
        decoration: BoxDecoration(
          color: pressed ? IqColors.secondary : IqColors.card,
          border: const Border(top: BorderSide(color: IqColors.line)),
        ),
        child: Row(
          children: [
            for (final (i, cell) in cells.indexed) ...[
              if (i > 0) const SizedBox(width: IqSpace.s6),
              ledgerCell(columns[i], cell),
            ],
            const SizedBox(width: IqSpace.s6),
            const IqIcon(IqIcons.forward, size: 16, color: IqColors.fg2),
          ],
        ),
      ),
    );
  }
}
