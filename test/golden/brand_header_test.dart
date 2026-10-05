import 'package:flutter/material.dart';
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
}
