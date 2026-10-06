import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/brand_header.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('centered layout', (tester) async {
    await expectComponentGolden(
      tester,
      'brand_header_centered',
      const SizedBox(width: 358, child: IqBrandHeader()),
      size: const Size(358, 207),
    );
  });

  testWidgets('leading layout', (tester) async {
    await expectComponentGolden(
      tester,
      'brand_header_leading',
      const SizedBox(
        width: 390,
        child: IqBrandHeader(layout: IqBrandHeaderLayout.leading),
      ),
      size: const Size(390, 288),
    );
  });

  group('the done line shows whole (480:22679)', () {
    const done =
        '2 answers sent. Orchid Foods shares the results in about a week.';

    for (final (layout, width) in [
      (IqBrandHeaderLayout.leading, 390.0),
      (IqBrandHeaderLayout.centered, 320.0),
    ]) {
      testWidgets(layout.name, (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: IqBrandHeader(layout: layout, detail: done),
                ),
              ),
            ),
          ),
        );
        final line = tester.renderObject<RenderParagraph>(find.text(done));
        expect(line.didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
