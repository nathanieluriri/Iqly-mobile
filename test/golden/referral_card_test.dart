import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/referral_card.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('referral_card', (tester) async {
    await expectComponentGolden(
      tester,
      'referral_card',
      const IqReferralCard(),
      size: IqReferralCard.size,
    );
  });
}
