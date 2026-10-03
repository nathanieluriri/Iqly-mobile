import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/highlight.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final tone in IqHighlightTone.values) {
    testWidgets('${tone.name} tone', (tester) async {
      await expectComponentGolden(
        tester,
        'highlight_${tone.name}',
        IqHighlight(tone: tone),
        size: const Size(96, 24),
        background: tone == IqHighlightTone.inverse
            ? IqColors.brand
            : IqColors.bg,
      );
    });
  }

  testWidgets('the marker holds still under reduced motion', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: IqHighlight(),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
  });
}
