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

  testWidgets('achievement_card name only', (tester) async {
    await expectComponentGolden(
      tester,
      'achievement_card_name_only',
      const IqAchievementCard(points: '', rank: ''),
      size: IqAchievementCard.size,
    );
  });
}
