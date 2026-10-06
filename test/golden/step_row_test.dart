import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/highlight.dart';
import 'package:iqly_mobile/ui/step_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  const heights = {
    IqStepRowState.todo: 65.0,
    IqStepRowState.active: 67.0,
    IqStepRowState.done: 65.0,
  };

  for (final state in IqStepRowState.values) {
    testWidgets('${state.name} state', (tester) async {
      await expectComponentGolden(
        tester,
        'step_row_${state.name}',
        SizedBox(width: 358, child: IqStepRow(state: state)),
        size: Size(358, heights[state]!),
      );
    });
  }

  testWidgets('completing a step pops the bubble and drops the mark', (
    tester,
  ) async {
    Widget row(IqStepRowState state) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(width: 358, child: IqStepRow(state: state)),
      ),
    );
    await tester.pumpWidget(row(IqStepRowState.active));
    await tester.pumpAndSettle();
    expect(find.byType(IqHighlight), findsOneWidget);
    await tester.pumpWidget(row(IqStepRowState.done));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(IqHighlight), findsNothing);
  });

  testWidgets('body and divider follow their props', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: IqStepRow(showBody: false, divider: false),
      ),
    );
    expect(
      find.text('Settings → Verification. About 2 minutes.'),
      findsNothing,
    );
    expect(find.byType(CustomPaint), findsNothing);
  });
}
