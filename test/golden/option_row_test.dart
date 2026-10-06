import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/option_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqOptionRowState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'option_row_${state.name}',
        SizedBox(
          width: 358,
          child: IqOptionRow(state: state, onTap: () {}),
        ),
        size: const Size(358, 56),
      );
    });
  }

  testWidgets('taps reach onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(home: IqOptionRow(onTap: () => taps++)),
    );
    await tester.tap(find.byType(IqOptionRow));
    expect(taps, 1);
  });
}
