import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/brief_hero.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('brief_hero', (tester) async {
    await expectComponentGolden(
      tester,
      'brief_hero',
      const SizedBox(width: 390, child: IqBriefHero()),
      size: const Size(390, 308),
      padding: 0,
    );
  });

  testWidgets('resized to 160, the logo keeps its overhang (35:146)', (
    tester,
  ) async {
    await expectComponentGolden(
      tester,
      'brief_hero_160',
      const SizedBox(
        width: 390,
        child: IqBriefHero(height: 160, showDots: false),
      ),
      size: const Size(390, 188),
      padding: 0,
    );
  });
}
