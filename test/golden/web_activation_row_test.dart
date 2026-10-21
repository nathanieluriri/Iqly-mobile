import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/biz_ledger_header.dart';
import 'package:iqly_mobile/ui/sample_cover.dart';
import 'package:iqly_mobile/ui/sample_logo.dart';
import 'package:iqly_mobile/ui/web_activation_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('in flight', (tester) async {
    await expectComponentGolden(
      tester,
      'web_activation_row',
      SizedBox(
        width: 868,
        child: IqWebActivationRow(
          columns: const [
            IqBizLedgerColumn('Activation', flex: 3),
            IqBizLedgerColumn('Reward', width: 92),
            IqBizLedgerColumn('Spots', width: 116),
            IqBizLedgerColumn('Closes', width: 150),
          ],
          business: 'Kudi Box',
          title: 'Open a Kudi Box account and save ₦1,000.00',
          status: 'Step 1 of 3 confirmed',
          statusWarm: true,
          cover: const IqSampleCover(IqSampleLogoBrand.kudiBox),
          logo: const IqSampleLogo(IqSampleLogoBrand.kudiBox),
          reward: '₦1,500',
          spots: '188 spots left',
          closes: Text(
            'Closes in 2 days',
            style: IqWebText.bodySmall.copyWith(color: IqColors.fg),
          ),
        ),
      ),
      size: const Size(868, 84),
    );
  });
}
