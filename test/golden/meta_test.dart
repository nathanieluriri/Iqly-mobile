import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/meta.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final kind in IqMetaKind.values) {
    testWidgets('${kind.name} kind', (tester) async {
      await expectComponentGolden(
        tester,
        'meta_${kind.name}',
        IqMeta(kind: kind),
        size: Size(kind == IqMetaKind.urgent ? 137 : 119, 26),
      );
    });
  }
}
