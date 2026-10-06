import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/share_card.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('default', (tester) async {
    await expectComponentGolden(
      tester,
      'share_card',
      const IqShareCard(),
      size: const Size(358, 418),
    );
  });

  testWidgets('captures at 3x', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: IqShareCard(key: key),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byKey(key));
    expect(size, const Size(358, 418));
    await tester.runAsync(() async {
      final image = await IqShareCard.capture(key);
      expect(image.width, 1074);
      expect(image.height, 1254);
    });
  });
}
