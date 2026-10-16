import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/chip.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqChipState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'chip_${state.name}',
        IqChip(state: state, onChanged: (_) {}),
        size: Size(state == IqChipState.selected ? 220 : 204, 44),
      );
    });
  }

  testWidgets('refused', (tester) async {
    await expectComponentGolden(
      tester,
      'chip_refused',
      IqChip(refused: true, onChanged: (_) {}),
      size: const Size(204, 44),
    );
  });

  testWidgets('tap toggles the state through onChanged', (tester) async {
    var state = IqChipState.standard;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => IqChip(
            state: state,
            onChanged: (next) => setState(() => state = next),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(IqChip));
    await tester.pumpAndSettle();
    expect(state, IqChipState.selected);
    await tester.tap(find.byType(IqChip));
    await tester.pumpAndSettle();
    expect(state, IqChipState.standard);
  });
}
