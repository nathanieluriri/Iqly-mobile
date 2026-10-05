import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/wallet_card.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final balance in IqWalletCardBalance.values) {
    for (final visibility in IqWalletCardVisibility.values) {
      final name = 'wallet_card_${balance.name}_${visibility.name}';
      testWidgets(name, (tester) async {
        await expectComponentGolden(
          tester,
          name,
          SizedBox(
            width: 358,
            child: IqWalletCard(balance: balance, visibility: visibility),
          ),
          size: const Size(358, 142),
        );
      });
    }
  }
}
