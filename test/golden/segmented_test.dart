import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/segmented.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final selected in IqSegmentedSelected.values) {
    testWidgets('${selected.name} selected', (tester) async {
      await expectComponentGolden(
        tester,
        'segmented_${selected.name}',
        SizedBox(width: 358, child: IqSegmented(selected: selected)),
        size: const Size(358, 40),
      );
    });
  }

  testWidgets('tapping an option reports it', (tester) async {
    IqSegmentedSelected? picked;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 358,
            child: IqSegmented(onChanged: (s) => picked = s),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Withdrawals'));
    expect(picked, IqSegmentedSelected.third);
  });
}
