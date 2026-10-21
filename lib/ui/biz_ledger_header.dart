import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// A column of a ledger: its label and its width, or a flex share when
/// [width] is null. [sorted] draws the descending sort mark.
class IqBizLedgerColumn {
  const IqBizLedgerColumn(
    this.label, {
    this.width,
    this.flex = 1,
    this.sorted = false,
    this.end = false,
  });

  final String label;
  final double? width;
  final int flex;
  final bool sorted;

  /// Lined up on the right (amounts).
  final bool end;
}

/// Exp/Biz/LedgerHeader (1743:22084): the grey head row of a table, 40
/// tall, 24 in, the column labels in fg2.
class IqBizLedgerHeader extends StatelessWidget {
  const IqBizLedgerHeader({
    super.key,
    required this.columns,
    this.trailing = 0,
  });

  final List<IqBizLedgerColumn> columns;

  /// Room kept at the end for the rows' chevron.
  final double trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: IqColors.secondary,
      padding: const EdgeInsets.symmetric(horizontal: IqSpace.s6),
      child: Row(
        children: [
          for (final (i, c) in columns.indexed) ...[
            if (i > 0) const SizedBox(width: IqSpace.s6),
            ledgerCell(c, _Label(c)),
          ],
          if (trailing > 0) ...[
            const SizedBox(width: IqSpace.s6),
            SizedBox(width: trailing),
          ],
        ],
      ),
    );
  }
}

/// Sizes [child] as [column] lays its cells out, for the rows under the
/// header to line up with it.
Widget ledgerCell(IqBizLedgerColumn column, Widget child) {
  final aligned = Align(
    alignment: column.end ? Alignment.centerRight : Alignment.centerLeft,
    child: child,
  );
  final width = column.width;
  return width != null
      ? SizedBox(width: width, child: aligned)
      : Expanded(flex: column.flex, child: aligned);
}

class _Label extends StatelessWidget {
  const _Label(this.column);

  final IqBizLedgerColumn column;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          column.label,
          style: IqWebText.metaCaption.copyWith(color: IqColors.fg2),
        ),
        if (column.sorted) ...[
          const SizedBox(width: IqSpace.s1),
          const _SortMark(),
        ],
      ],
    );
  }
}

/// Exp/Biz/SortIcon, Direction=Descending: the up mark in line2, the down
/// mark in primary.
class _SortMark extends StatelessWidget {
  const _SortMark();

  @override
  Widget build(BuildContext context) {
    Widget mark(bool up) => CustomPaint(
      size: const Size(6, 3),
      painter: _Triangle(up: up, color: up ? IqColors.line2 : IqColors.primary),
    );
    return SizedBox(
      width: 12,
      height: 12,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          mark(true),
          const SizedBox(height: IqSpace.s0p5),
          mark(false),
        ],
      ),
    );
  }
}

class _Triangle extends CustomPainter {
  const _Triangle({required this.up, required this.color});

  final bool up;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = up
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Triangle old) => old.up != up || old.color != color;
}
