import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/podium.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('podium', (tester) async {
    await expectComponentGolden(
      tester,
      'podium',
      const SizedBox(width: 358, child: IqPodium()),
      size: const Size(358, 236),
    );
  });
}
