import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/section_title.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('default', (tester) async {
    await expectComponentGolden(
      tester,
      'section_title',
      const SizedBox(width: 358, child: IqSectionTitle()),
      size: const Size(358, 33),
    );
  });

  testWidgets('without count and link', (tester) async {
    await expectComponentGolden(
      tester,
      'section_title_bare',
      const SizedBox(
        width: 358,
        child: IqSectionTitle(showCount: false, showLink: false),
      ),
      size: const Size(358, 33),
    );
  });

  testWidgets('See all reaches onSeeAll', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IqSectionTitle(onSeeAll: () => taps++)),
      ),
    );
    await tester.tap(find.text('See all'));
    expect(taps, 1);
  });
}
