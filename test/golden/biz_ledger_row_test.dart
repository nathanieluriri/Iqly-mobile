import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/biz_ledger_header.dart';
import 'package:iqly_mobile/ui/biz_ledger_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a ledger line', (tester) async {
    const columns = [
      IqBizLedgerColumn('Date', width: 72),
      IqBizLedgerColumn('Description', flex: 3),
      IqBizLedgerColumn('Amount', width: 120, end: true),
    ];
    await expectComponentGolden(
      tester,
      'biz_ledger_row',
      SizedBox(
        width: 670,
        child: IqBizLedgerRow(
          columns: columns,
          cells: [
            Text(
              '20 Oct',
              style: IqWebText.bodySmall.copyWith(color: IqColors.fg2),
            ),
            Text(
              'To Access Bank ••6789',
              style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
            ),
            Text(
              '−₦10,000.00',
              style: IqWebText.bodySmallStrong.copyWith(color: IqColors.fg),
            ),
          ],
        ),
      ),
      size: const Size(670, 64),
    );
  });
}
