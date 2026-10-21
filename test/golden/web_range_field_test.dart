import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/web_range_field.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('full range', (tester) async {
    await expectComponentGolden(
      tester,
      'web_range_field',
      const SizedBox(
        width: 224,
        child: Material(
          type: MaterialType.transparency,
          child: IqWebRangeField(min: '₦80,000', max: '₦600,000'),
        ),
      ),
      size: const Size(224, 80),
    );
  });
}
