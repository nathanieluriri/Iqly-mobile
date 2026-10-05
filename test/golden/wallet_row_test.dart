import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/brand_logo.dart';
import 'package:iqly_mobile/ui/wallet_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('award kind', (tester) async {
    await expectComponentGolden(
      tester,
      'wallet_row_award',
      const SizedBox(width: 358, child: IqWalletRow()),
      size: const Size(358, 64),
    );
  });

  testWidgets('referral award keeps the square logomark', (tester) async {
    await expectComponentGolden(
      tester,
      'wallet_row_referral',
      const SizedBox(
        width: 358,
        child: IqWalletRow(
          title: 'Referral bonus',
          detail: 'Reward · Ngozi E. won a first brief',
          amount: '+₦500.00',
          when: '5 days ago',
          logo: IqBrandLogo(
            mark: IqBrandMark.logomark,
            tone: IqBrandTone.onDark,
            width: 40,
            height: 40,
          ),
        ),
      ),
      size: const Size(358, 64),
    );
  });

  const amounts = {
    IqWalletRowStatus.pending: '−₦10,000.00',
    IqWalletRowStatus.completed: '−₦40,000.00',
    IqWalletRowStatus.failed: '₦5,000.00',
    IqWalletRowStatus.reversed: '₦5,000.00',
  };
  for (final status in IqWalletRowStatus.values) {
    testWidgets('withdrawal ${status.name}', (tester) async {
      await expectComponentGolden(
        tester,
        'wallet_row_withdrawal_${status.name}',
        SizedBox(
          width: 358,
          child: IqWalletRow(
            kind: IqWalletRowKind.withdrawal,
            title: 'To Access Bank',
            status: status,
            amount: amounts[status]!,
            when: '2 hours ago',
          ),
        ),
        size: const Size(358, 64),
      );
    });
  }
}
