import 'package:flutter/widgets.dart';

import '../theme/theme.dart';
import 'biz_ledger_header.dart';
import 'pressable.dart';

/// Exp/Biz/LedgerRow (1743:22128): one line of a ledger, 64 tall, 24 in,
/// its [cells] laid out by the header's [columns]. A row that opens
/// something takes the tap and greys while pressed.
class IqBizLedgerRow extends StatelessWidget {
  const IqBizLedgerRow({
    super.key,
    required this.columns,
    required this.cells,
    this.onTap,
    this.semanticLabel,
  });

  final List<IqBizLedgerColumn> columns;
  final List<Widget> cells;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return IqPressable(
      onTap: onTap,
      tactile: false,
      semanticLabel: semanticLabel,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(
          horizontal: IqSpace.s6,
          vertical: IqSpace.s3,
        ),
        decoration: BoxDecoration(
          color: pressed && onTap != null ? IqColors.secondary : IqColors.card,
          border: const Border(top: BorderSide(color: IqColors.line)),
        ),
        child: Row(
          children: [
            for (final (i, cell) in cells.indexed) ...[
              if (i > 0) const SizedBox(width: IqSpace.s6),
              ledgerCell(columns[i], cell),
            ],
          ],
        ),
      ),
    );
  }
}
