import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'biz_ledger_header.dart';
import 'biz_status_pill.dart';
import 'icon.dart';
import 'pressable.dart';

/// Figma State=Default is [standard].
enum IqWebSubmissionRowState { standard, selected }

/// Exp/Web/SubmissionRow (local, sync to DS; 1734:18046): one row of the My
/// submissions table, 72 tall, 24 in. The 44 thumb beside the title and
/// the brief, the status pill over its note, then the optional Reward and
/// Sent cells and the chevron. Selected is the grey row; there is no
/// hover. [columns] are the table's, so the cells line up with the header:
/// the first two are the submission and the status, then Reward when
/// [reward] is given and Sent when [sent] is.
class IqWebSubmissionRow extends StatelessWidget {
  const IqWebSubmissionRow({
    super.key,
    required this.columns,
    required this.title,
    required this.brief,
    required this.thumb,
    required this.status,
    this.statusLabel,
    this.note,
    this.reward,
    this.sent,
    this.state = IqWebSubmissionRowState.standard,
    this.onTap,
  });

  final List<IqBizLedgerColumn> columns;
  final String title;
  final String brief;
  final Widget thumb;
  final IqBizStatusPillStatus status;
  final String? statusLabel;
  final String? note;
  final String? reward;
  final String? sent;
  final IqWebSubmissionRowState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    final cells = <Widget>[
      Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(IqRadius.lg),
            child: SizedBox.square(dimension: 44, child: thumb),
          ),
          const SizedBox(width: IqSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqWebText.bodySmallStrong.copyWith(color: IqColors.fg),
                ),
                const SizedBox(height: IqSpace.s0p5),
                Text(
                  brief,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
                ),
              ],
            ),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          IqBizStatusPill(status: status, label: statusLabel),
          if (note != null) ...[
            const SizedBox(height: IqSpace.s1),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: IqWebText.metaCaption.copyWith(color: IqColors.fg3),
            ),
          ],
        ],
      ),
      if (reward case final reward?)
        Text(reward, style: IqWebText.bodySmall.copyWith(color: IqColors.fg)),
      if (sent case final sent?)
        Text(sent, style: IqWebText.bodySmall.copyWith(color: IqColors.fg3)),
    ];
    return IqPressable(
      onTap: onTap,
      tactile: false,
      semanticLabel: '$title, ${statusLabel ?? status.label}',
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s6,
          vertical: IqSpace.s3,
        ),
        decoration: BoxDecoration(
          color: state == IqWebSubmissionRowState.selected || pressed
              ? IqColors.secondary
              : IqColors.card,
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
