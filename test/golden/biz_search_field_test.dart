import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/biz_search_field.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('empty', (tester) async {
    await expectComponentGolden(
      tester,
      'biz_search_field',
      const SizedBox(width: 320, child: IqBizSearchField()),
      size: const Size(320, 44),
    );
  });
}
