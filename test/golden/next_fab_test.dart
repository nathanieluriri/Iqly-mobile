import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/next_fab.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqNextFabState.values) {
    final name = 'next_fab_${state.name}';
    testWidgets(name, (tester) async {
      await expectComponentGolden(
        tester,
        name,
        IqNextFab(state: state, onTap: () {}),
        size: const Size(60, 60),
      );
    });
  }

  testWidgets('next_fab_pressed', (tester) async {
    await expectPressedComponentGolden(
      tester,
      'next_fab_pressed',
      IqNextFab(state: IqNextFabState.enabled, onTap: () {}),
      size: const Size(60, 60),
    );
  });

  testWidgets('only Enabled reaches onTap', (tester) async {
    var taps = 0;
    for (final state in IqNextFabState.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IqNextFab(state: state, onTap: () => taps++),
          ),
        ),
      );
      await tester.tap(find.byType(IqNextFab));
    }
    expect(taps, 1);
  });
}
