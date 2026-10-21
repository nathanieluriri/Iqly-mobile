import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/biz_ledger_header.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('submissions columns', (tester) async {
    await expectComponentGolden(
      tester,
      'biz_ledger_header',
      const SizedBox(
        width: 670,
        child: IqBizLedgerHeader(
          columns: [
            IqBizLedgerColumn('Submission', flex: 2),
            IqBizLedgerColumn('Status', width: 150),
            IqBizLedgerColumn('Sent', width: 96, sorted: true),
          ],
          trailing: 16,
        ),
      ),
      size: const Size(670, 40),
    );
  });
}
