import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/draft_row.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  const variants = {
    'draft_row_default': IqDraftRow(),
    'draft_row_selecting': IqDraftRow(mode: IqDraftRowMode.selecting),
    'draft_row_selecting_selected': IqDraftRow(
      mode: IqDraftRowMode.selecting,
      selected: true,
    ),
  };
  for (final entry in variants.entries) {
    testWidgets(entry.key, (tester) async {
      await expectComponentGolden(
        tester,
        entry.key,
        SizedBox(width: 358, child: entry.value),
        size: const Size(358, 85),
      );
    });
  }

  testWidgets('steps fill the bar', (tester) async {
    await expectComponentGolden(
      tester,
      'draft_row_all_steps',
      const SizedBox(width: 358, child: IqDraftRow(step3Done: true)),
      size: const Size(358, 85),
    );
  });

  testWidgets('measures 85 high and reports long press', (tester) async {
    var held = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 358,
            child: IqDraftRow(onTap: () {}, onLongPress: () => held++),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(IqDraftRow)).height, 85);
    await tester.longPress(find.byType(IqDraftRow));
    expect(held, 1);
  });
}
