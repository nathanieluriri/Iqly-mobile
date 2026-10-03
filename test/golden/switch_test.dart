import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/switch.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqSwitchState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'switch_${state.name}',
        IqSwitch(state: state, onChanged: (_) {}),
        size: const Size(52, 32),
      );
    });
  }

  testWidgets('tap flips the state', (tester) async {
    var state = IqSwitchState.off;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: IqSwitch(
              state: state,
              onChanged: (next) => setState(() => state = next),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IqSwitch));
    await tester.pumpAndSettle();
    expect(state, IqSwitchState.on);
  });
}
