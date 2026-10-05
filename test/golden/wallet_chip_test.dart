import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/wallet_chip.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('wallet_chip', (tester) async {
    await expectComponentGolden(
      tester,
      'wallet_chip',
      const IqWalletChip(),
      size: const Size(108, 44),
    );
  });
}
