import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/pull_indicator.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqPullIndicatorState.values) {
    final name = 'pull_indicator_${state.name}';
    testWidgets(name, (tester) async {
      await expectComponentGolden(
        tester,
        name,
        stillMotion(IqPullIndicator(state: state)),
        size: const Size(358, 40),
      );
    });
  }

  testWidgets('Pull fades in over the first 64 px', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IqPullIndicator(pullExtent: 32))),
    );
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(IqPullIndicator),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.5,
    );
  });

  testWidgets('Refreshing turns the loop', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IqPullIndicator(state: IqPullIndicatorState.refreshing),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));
    final turns = tester
        .widget<RotationTransition>(
          find.descendant(
            of: find.byType(IqPullIndicator),
            matching: find.byType(RotationTransition),
          ),
        )
        .turns
        .value;
    expect(turns, closeTo(0.5, 0.01));
  });
}
