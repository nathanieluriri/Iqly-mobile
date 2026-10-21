import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iqly_mobile/ui/icon.dart';
import 'package:iqly_mobile/ui/tablet_nav_item.dart';

import 'golden.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final layout in IqTabletNavItemLayout.values) {
    for (final state in IqTabletNavItemState.values) {
      testWidgets('${layout.name} ${state.name}', (tester) async {
        final rail = layout == IqTabletNavItemLayout.rail;
        await expectComponentGolden(
          tester,
          'tablet_nav_item_${layout.name}_${state.name}',
          IqTabletNavItem(
            label: 'Discover',
            icon: IqIcons.discover,
            layout: layout,
            state: state,
          ),
          size: rail ? const Size(80, 64) : const Size(216, 48),
        );
      });
    }
  }
}
