import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/biz_nav_item.dart';
import 'package:iqly_mobile/ui/icon.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final state in IqBizNavItemState.values) {
    testWidgets(state.name, (tester) async {
      await expectComponentGolden(
        tester,
        'biz_nav_item_${state.name}',
        SizedBox(
          width: 184,
          child: IqBizNavItem(
            label: 'Your details',
            icon: IqIcons.profile,
            state: state,
          ),
        ),
        size: const Size(184, 44),
      );
    });
  }
}
