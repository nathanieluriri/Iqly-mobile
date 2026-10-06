import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/claim_stamp.dart';

import 'golden.dart';
import 'press.dart';

void main() {
  setUpAll(loadAppFonts);

  const sizes = {
    IqClaimStampKind.pending: Size(85, 34),
    IqClaimStampKind.checking: Size(107, 35),
    IqClaimStampKind.verified: Size(93, 34),
    IqClaimStampKind.credited: Size(141, 36),
    IqClaimStampKind.needsInfo: Size(109, 35),
    IqClaimStampKind.rejected: Size(125, 36),
  };

  for (final kind in IqClaimStampKind.values) {
    testWidgets('${kind.name} kind', (tester) async {
      await expectComponentGolden(
        tester,
        'claim_stamp_${kind.name}',
        stillMotion(IqClaimStamp(kind: kind)),
        size: sizes[kind]!,
      );
    });
  }

  testWidgets('a new kind lands the stamp', (tester) async {
    Widget stamp(IqClaimStampKind kind) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: IqClaimStamp(kind: kind)),
    );
    await tester.pumpWidget(stamp(IqClaimStampKind.pending));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(stamp(IqClaimStampKind.verified));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Verified'), findsOneWidget);
  });

  testWidgets('checking pulses its dot, still under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: IqClaimStamp(kind: IqClaimStampKind.checking)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: IqClaimStamp(kind: IqClaimStampKind.checking)),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
