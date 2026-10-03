import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/setting_row.dart';
import 'package:iqly_mobile/ui/switch.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqSwitchState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'setting_row_${state.name}',
        SizedBox(
          width: 358,
          child: IqSettingRow(state: state, onChanged: (_) {}),
        ),
        size: const Size(358, 64),
      );
    });
  }

  testWidgets('tapping anywhere on the row flips the switch', (tester) async {
    var state = IqSwitchState.off;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => IqSettingRow(
              state: state,
              onChanged: (next) => setState(() => state = next),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Brief closing soon'));
    await tester.pumpAndSettle();
    expect(state, IqSwitchState.on);
    await tester.tap(find.byType(IqSwitch));
    await tester.pumpAndSettle();
    expect(state, IqSwitchState.off);
  });
}
