import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/biz_ledger_header.dart';
import 'package:iqly_mobile/ui/biz_status_pill.dart';
import 'package:iqly_mobile/ui/web_submission_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqWebSubmissionRowState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'web_submission_row_${state.name}',
        SizedBox(
          width: 670,
          child: IqWebSubmissionRow(
            columns: const [
              IqBizLedgerColumn('Submission', flex: 2),
              IqBizLedgerColumn('Status', width: 150),
              IqBizLedgerColumn('Sent', width: 96),
            ],
            title: 'Bring the shop to the hostel',
            brief: 'How should a campus bookshop sell online?',
            thumb: const ColoredBox(color: IqColors.tintStrong),
            status: IqBizStatusPillStatus.underReview,
            note: 'Closes in 20 days',
            sent: '1 day ago',
            state: state,
          ),
        ),
        size: const Size(670, 72),
      );
    });
  }
}
