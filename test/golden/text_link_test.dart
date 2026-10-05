import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/text_link.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('text_link', (tester) async {
    await expectComponentGolden(
      tester,
      'text_link',
      const IqTextLink(),
      size: const Size(80, 44),
    );
  });

  testWidgets('the link is 44 tall', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: IqTextLink()),
      ),
    );
    expect(tester.getSize(find.byType(IqTextLink)).height, 44);
  });
}
