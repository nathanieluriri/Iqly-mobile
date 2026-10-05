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
      size: const Size(358, 32),
    );
  });

  testWidgets('with count and underline', (tester) async {
    await expectComponentGolden(
      tester,
      'section_title_count',
      const SizedBox(
        width: 358,
        child: IqSectionTitle(showCount: true, showUnderline: true),
      ),
      size: const Size(358, 32),
    );
  });

  testWidgets('without link', (tester) async {
    await expectComponentGolden(
      tester,
      'section_title_bare',
      const SizedBox(width: 358, child: IqSectionTitle(showLink: false)),
      size: const Size(358, 32),
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

  testWidgets('See all takes taps across a 44 pt band', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 40),
              IqSectionTitle(onSeeAll: () => taps++),
            ],
          ),
        ),
      ),
    );
    final link = tester.getCenter(find.text('See all'));
    final box = tester.getRect(find.byType(IqSectionTitle));
    await tester.tapAt(Offset(link.dx, box.top - 5));
    await tester.tapAt(Offset(link.dx, box.bottom + 5));
    expect(box.height, lessThan(44));
    expect(taps, 2);
  });
}
