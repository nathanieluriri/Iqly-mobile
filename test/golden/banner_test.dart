import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/banner.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final kind in IqBannerKind.values) {
    testWidgets(kind.name, (tester) async {
      await expectComponentGolden(
        tester,
        'banner_${kind.name}',
        SizedBox(width: 358, child: stillMotion(IqBanner(kind: kind))),
        size: Size(358, kind == IqBannerKind.offline ? 60 : 46),
      );
    });
  }

  testWidgets('action taps reach onAction and dismiss collapses', (
    tester,
  ) async {
    var taps = 0;
    Widget build(bool visible) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            IqBanner(
              kind: IqBannerKind.error,
              visible: visible,
              onAction: () => taps++,
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build(true));
    await tester.pump(IqBanner.enter);
    await tester.tap(find.text('Try again'));
    expect(taps, 1);
    await tester.pumpWidget(build(false));
    await tester.pump(IqBanner.exit);
    await tester.pump();
    expect(tester.getSize(find.byType(IqBanner)).height, 0);
  });
}
