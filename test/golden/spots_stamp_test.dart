import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/spots_stamp.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  const masters = {
    IqSpotsStampTone.plenty: 188,
    IqSpotsStampTone.low: 38,
    IqSpotsStampTone.critical: 12,
    IqSpotsStampTone.full: 0,
  };

  for (final entry in masters.entries) {
    testWidgets('${entry.key.name} tone', (tester) async {
      await expectComponentGolden(
        tester,
        'spots_stamp_${entry.key.name}',
        SizedBox(
          width: 358,
          child: IqSpotsStamp(left: entry.value, tone: entry.key),
        ),
        size: const Size(358, 46),
      );
    });
  }

  testWidgets('the figure counts up to the spots left', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 358, child: IqSpotsStamp()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('188'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('188'), findsOneWidget);
    expect(find.text('312 / 500 TAKEN'), findsOneWidget);
  });

  testWidgets('reduced motion shows the final values at once', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 358, child: IqSpotsStamp()),
        ),
      ),
    );
    expect(find.text('188'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  test('tone follows the ladder', () {
    expect(IqSpotsStampTone.of(188, 500), IqSpotsStampTone.plenty);
    expect(IqSpotsStampTone.of(100, 500), IqSpotsStampTone.low);
    expect(IqSpotsStampTone.of(12, 500), IqSpotsStampTone.critical);
    expect(IqSpotsStampTone.of(0, 500), IqSpotsStampTone.full);
  });
}
