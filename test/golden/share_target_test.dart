import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/share_target.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final kind in IqShareTargetKind.values) {
    testWidgets('kind ${kind.name}', (tester) async {
      await expectComponentGolden(
        tester,
        'share_target_${kind.name}',
        IqShareTarget(kind: kind),
        size: const Size(72, 82),
      );
    });
  }

  testWidgets('pressed', (tester) async {
    await expectPressedComponentGolden(
      tester,
      'share_target_pressed',
      IqShareTarget(onTap: () {}),
      size: const Size(72, 82),
    );
  });

  testWidgets('taps reach onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IqShareTarget(
            kind: IqShareTargetKind.copyLink,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Copy link'));
    expect(taps, 1);
  });
}
