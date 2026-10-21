import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/theme/theme.dart';
import 'package:iqly_mobile/ui/tablet_icon.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('the tablet icons', (tester) async {
    await expectComponentGolden(
      tester,
      'tablet_icons',
      Row(
        children: [
          for (final icon in IqTabletIcons.values) ...[
            IqTabletIcon(icon, color: IqColors.brand),
            const SizedBox(width: IqSpace.s2),
          ],
        ],
      ),
      size: const Size(160, 24),
    );
  });
}
