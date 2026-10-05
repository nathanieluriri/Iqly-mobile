import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/achievement_card.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('achievement_card', (tester) async {
    await expectComponentGolden(
      tester,
      'achievement_card',
      const IqAchievementCard(),
      size: IqAchievementCard.size,
    );
  });
}
