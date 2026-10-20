import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/support_sticker.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final size in IqSupportStickerSize.values) {
    testWidgets('${size.name} size', (tester) async {
      final side = size == IqSupportStickerSize.large ? 40.0 : 20.0;
      await expectComponentGolden(
        tester,
        'support_sticker_${size.name}',
        IqSupportSticker(size: size),
        size: Size(side, side),
      );
    });
  }
}
