import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/list_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('default tone', (tester) async {
    await expectComponentGolden(
      tester,
      'list_row_standard',
      const SizedBox(width: 358, child: IqListRow()),
      size: const Size(358, 64),
    );
  });

  testWidgets('danger tone', (tester) async {
    await expectComponentGolden(
      tester,
      'list_row_danger',
      const SizedBox(
        width: 358,
        child: IqListRow(label: 'Sign out', tone: IqListRowTone.danger),
      ),
      size: const Size(358, 64),
    );
  });

  testWidgets('taps reach onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IqListRow(onTap: () => taps++)),
      ),
    );
    await tester.tap(find.byType(IqListRow));
    expect(taps, 1);
  });
}
